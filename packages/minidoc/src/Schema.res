// Config and frontmatter schemas — Sury parses the YAML: build entries into
// typed records whose paths `convert` anchors to the declaring config's
// directory, var blocks and frontmatter into plain trees.

external magic: 'a => 'b = "%identity"

let fail = JsError.throwWithMessage

// Run `fn`, prefixing any thrown Error message with `prefix` (schema errors
// then read "config.yaml: ...").
// Sury errors expose `message` as a getter only: those are rethrown as a
// plain Error carrying the original as `cause`.
let rawGuard: (string, unit => unknown) => unknown = %raw(`(prefix, fn) => {
  try { return fn() } catch (e) {
    const message = prefix + ": " + e.message
    try { e.message = message } catch { throw new Error(message, { cause: e }) }
    throw e
  }
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

/** Listing order: by path, ascending (the default) or descending. */
type order = | @as("asc") Asc | @as("desc") Desc

/** A folder of content files for `pages`. `optional` accepts an empty match
 (or a missing folder). */
type source = {
  dir: string,
  glob: option<string>,
  transform: option<string>,
  optional: option<bool>,
  order: option<order>,
}

/** A var block or a frontmatter block, as written: scalars, scalar lists and
 nested mappings. What a mapping *is* (a file, a dir, a plain group) is
 decided when it is read, after every layer has merged. */
type rec tree =
  | Str(string)
  | Strs(array<string>)
  | Tree(dict<tree>)

type inputv =
  | Text(string)
  | Copy(string)
  | Node(dict<tree>)

type buildv = {vars: dict<tree>, pages: option<source>, output: string, input: inputv}
type configv = {path: string, vars: dict<tree>, base: option<string>, build: array<buildv>}

/** An evaluated value: a scalar or a list of scalars. */
type data = One(string) | Many(array<string>)

type rawbuild = {vars: option<dict<tree>>, pages: option<source>, output: string, input: inputv}
type rawconfig = {vars: option<dict<tree>>, base: option<string>, build: option<array<rawbuild>>}

// Missing and explicit-null keys both read as None.
let opt = s => S.nullableAsOption(s)

// A YAML scalar of any type reads as its string form.
let scalarS = S.union([S.string, S.float->S.to(S.string), S.bool->S.to(S.string)])

let orderS = S.enum([Asc, Desc])

let sourceS = S.object((s): source => {
  dir: s.field("dir", S.string),
  glob: s.field("glob", opt(S.string)),
  transform: s.field("transform", opt(S.string)),
  optional: s.field("optional", opt(S.bool)),
  order: s.field("order", opt(orderS)),
})

let treeS = S.recursive("Tree", treeS =>
  S.union([
    scalarS->S.shape(s => Str(s)),
    S.array(scalarS)->S.shape(a => Strs(a)),
    S.dict(treeS)->S.shape(d => Tree(d)),
  ])
)

let inputS = S.union([
  S.string->S.shape(t => Text(t)),
  S.object(s => Copy(s.field("copy", S.string))),
  S.dict(treeS)->S.shape(d => Node(d)),
])

let buildS = S.object((s): rawbuild => {
  vars: s.field("var", opt(S.dict(treeS))),
  pages: s.field("pages", opt(sourceS)),
  output: s.field("output", S.string),
  input: s.field("input", inputS),
})

let configS = S.object((s): rawconfig => {
  vars: s.field("var", opt(S.dict(treeS))),
  base: s.field("base", opt(S.string)),
  build: s.field("build", opt(S.array(buildS))),
})

let frontS = opt(S.dict(treeS))

// Typed paths anchor here, at parse time. Paths inside var trees carry their
// declaring directory instead and anchor when they are read.
let convert = (path, raw: rawconfig): configv => {
  let dir = dirname(path)
  {
    path,
    vars: raw.vars->Option.getOr(Dict.make()),
    base: raw.base->Option.map(join(dir, ...)),
    build: raw.build
    ->Option.getOr([])
    ->Array.map((b): buildv => {
      vars: b.vars->Option.getOr(Dict.make()),
      pages: b.pages->Option.map(p => {...p, dir: join(dir, p.dir)}),
      output: join(dir, b.output),
      input: switch b.input {
      | Copy(c) => Copy(join(dir, c))
      | input => input
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
