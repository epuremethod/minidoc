// Config and frontmatter schemas — Sury parses the YAML into tagged variants,
// then `convert` anchors every declared path to the declaring config's
// directory, before any var interpolation.

external magic: 'a => 'b = "%identity"

let fail = JsError.throwWithMessage

// Run `fn`, prefixing any thrown Error message with `prefix` (schema errors
// then read "config.yaml: ...").
let rawGuard: (string, unit => unknown) => unknown = %raw(`(prefix, fn) => {
  try { return fn() } catch (e) { e.message = prefix + ": " + e.message; throw e }
}`)
let guard = (prefix, fn: unit => 'a): 'a => magic(rawGuard(prefix, magic(fn)))

module Yaml = {
  @module("yaml") external parse: string => 'a = "parse"

  // The editable document: `parseDocument` keeps comments and layout, so a
  // config written back is the file the author wrote plus the one key.
  type doc
  @module("yaml") external parseDocument: string => doc = "parseDocument"
  @send external getIn: (doc, array<string>) => Nullable.t<'a> = "getIn"
  @send external setIn: (doc, array<string>, int) => unit = "setIn"
  @send external print: doc => string = "toString"
}

// Paths are posix-style with no `..` normalization: used as written.
let dirname = path => {
  let i = String.lastIndexOf(path, "/")
  i < 0 ? "" : String.slice(path, ~start=0, ~end=i)
}

let join = (dir, path) => dir == "" || String.startsWith(path, "/") ? path : `${dir}/${path}`

type filev = {file: string, transform: option<string>}
type dirv = {dir: string, glob: option<string>, each: option<string>, transform: option<string>}
type listv = {list: string, each: string, join: option<string>, template: option<string>}
type pipev = {value: string, transform: string}

type varv =
  | Scalar(string)
  | Scalars(array<string>)
  | FileV(filev)
  | DirV(dirv)
  | ListV(listv)
  | PipeV(pipev)

type inputv =
  | Text(string)
  | FileI(filev)
  | DirI(dirv)
  | Copy(string)

type buildv = {vars: dict<varv>, output: string, input: inputv}
type configv = {vars: dict<varv>, base: option<string>, build: array<buildv>}

/** A frontmatter value: a scalar or a list of scalars. */
type data = One(string) | Many(array<string>)

type rawbuild = {vars: option<dict<varv>>, output: string, input: inputv}
type rawconfig = {vars: option<dict<varv>>, base: option<string>, build: option<array<rawbuild>>}

// Missing and explicit-null keys both read as None.
let opt = s => S.nullableAsOption(s)

// A YAML scalar of any type reads as its string form.
let scalarS = S.union([S.string, S.float->S.to(S.string), S.bool->S.to(S.string)])

let fileS = S.object((s): filev => {
  file: s.field("file", S.string),
  transform: s.field("transform", opt(S.string)),
})

let dirS = S.object((s): dirv => {
  dir: s.field("dir", S.string),
  glob: s.field("glob", opt(S.string)),
  each: s.field("each", opt(S.string)),
  transform: s.field("transform", opt(S.string)),
})

let listS = S.object((s): listv => {
  list: s.field("list", S.string),
  each: s.field("each", S.string),
  join: s.field("join", opt(S.string)),
  template: s.field("template", opt(S.string)),
})

let pipeS = S.object((s): pipev => {
  value: s.field("value", S.string),
  transform: s.field("transform", S.string),
})

let varS = S.union([
  scalarS->S.shape(s => Scalar(s)),
  S.array(scalarS)->S.shape(a => Scalars(a)),
  dirS->S.shape(d => DirV(d)),
  fileS->S.shape(f => FileV(f)),
  listS->S.shape(l => ListV(l)),
  pipeS->S.shape(p => PipeV(p)),
])

let inputS = S.union([
  S.string->S.shape(t => Text(t)),
  S.object(s => Copy(s.field("copy", S.string))),
  dirS->S.shape(d => DirI(d)),
  fileS->S.shape(f => FileI(f)),
])

let buildS = S.object((s): rawbuild => {
  vars: s.field("var", opt(S.dict(varS))),
  output: s.field("output", S.string),
  input: s.field("input", inputS),
})

let configS = S.object((s): rawconfig => {
  vars: s.field("var", opt(S.dict(varS))),
  base: s.field("base", opt(S.string)),
  build: s.field("build", opt(S.array(buildS))),
})

let dataS = S.union([scalarS->S.shape(s => One(s)), S.array(scalarS)->S.shape(a => Many(a))])
let frontS = opt(S.dict(dataS))

let anchor = (dir, v) =>
  switch v {
  | FileV(f) => FileV({...f, file: join(dir, f.file)})
  | DirV(d) => DirV({...d, dir: join(dir, d.dir)})
  | v => v
  }

let convert = (path, raw: rawconfig): configv => {
  let dir = dirname(path)
  {
    vars: raw.vars->Option.getOr(Dict.make())->Dict.mapValues(anchor(dir, ...)),
    base: raw.base->Option.map(join(dir, ...)),
    build: raw.build
    ->Option.getOr([])
    ->Array.map((b): buildv => {
      vars: b.vars->Option.getOr(Dict.make())->Dict.mapValues(anchor(dir, ...)),
      output: join(dir, b.output),
      input: switch b.input {
      | Text(t) => Text(t)
      | Copy(c) => Copy(join(dir, c))
      | FileI(f) => FileI({...f, file: join(dir, f.file)})
      | DirI(d) => DirI({...d, dir: join(dir, d.dir)})
      },
    }),
  }
}

/** Parse and validate one config file. `path` locates it in error messages. */
let parse = (text, path) => guard(path, () => convert(path, S.parseOrThrow(Yaml.parse(text), ~to=configS)))

/** Parse a frontmatter YAML block. `at` locates the file in error messages. */
let front = (head, at) => guard(at, () => S.parseOrThrow(Yaml.parse(head), ~to=frontS)->Option.getOr(Dict.make()))

// ---------------------------------------------------------------------------
// The dev server port, remembered in the entry config.

// A dev server on a fixed port collides with every other project on the
// machine, so the port is drawn once and written back to the config that
// declared the site. It lives under `var` like any other scalar: a template
// can say `{{port}}`.

/** The port remembered in `var: port:`, when the config names one. */
let port = text =>
  try {
    switch Yaml.parseDocument(text)->Yaml.getIn(["var", "port"])->Nullable.toOption {
    | None => None
    | Some(v) =>
      switch Type.typeof(v) {
      | #number => Some(magic(v): int)
      | #string => Int.fromString(magic(v))
      | _ => None
      }
    }
  } catch {
  | _ => None
  }

/** `text` with `var: port:` set to `n`; every other byte stays as written. */
let withPort = (text, n) => {
  let doc = Yaml.parseDocument(text)
  doc->Yaml.setIn(["var", "port"], n)
  doc->Yaml.print
}
