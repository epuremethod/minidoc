// minidoc — a small documentation website generator.
// Schema.res owns the config/frontmatter parsing; this module resolves and runs.

open Schema

external magic: 'a => 'b = "%identity"

module Md = {
  type opts = {@as("async") sync: bool}
  @module("marked") @scope("marked") external parse: (string, opts) => string = "parse"
}

// Await each item in order — sequential, unlike Promise.all.
let rec seq = async (xs, i, fn) =>
  if i < Array.length(xs) {
    await fn(Array.getUnsafe(xs, i))
    await seq(xs, i + 1, fn)
  }

let special = RegExp.fromString("[.*+?^${}()|[\\]\\\\]", ~flags="g")
let slashes = RegExp.fromString("\\\\", ~flags="g")

// Compile a `*`/`**` glob into a path predicate. `*` never crosses `/`; `**` does.
let matcher = glob => {
  let rec build = (i, out) =>
    if i >= String.length(glob) {
      out
    } else if String.charAt(glob, i) != "*" {
      build(i + 1, out ++ String.replaceRegExp(String.charAt(glob, i), special, "\\$&"))
    } else if String.charAt(glob, i + 1) != "*" {
      build(i + 1, out ++ "[^/]*")
    } else if String.charAt(glob, i + 2) == "/" {
      build(i + 3, out ++ "(?:.*/)?")
    } else {
      build(i + 2, out ++ ".*")
    }
  let re = RegExp.fromString(`^${build(0, "")}$`)
  name => re->RegExp.test(String.replaceRegExp(name, slashes, "/"))
}

// ---------------------------------------------------------------------------
// Frontmatter — an optional leading `---` YAML block of scalars/scalar lists.

type parsed = {front: dict<data>, body: string}

let matter = RegExp.fromString("^---\\n(?:([\\s\\S]*?)\\n)?---(?:\\n|$)")

let split = (text, at) =>
  if !String.startsWith(text, "---\n") {
    {front: Dict.make(), body: text}
  } else {
    switch RegExp.exec(matter, text) {
    | None => fail(`${at}: unterminated frontmatter (missing closing "---" line)`)
    | Some(m) =>
      let vars = switch m->RegExp.Result.matches->Array.get(0) {
      | Some(Some(head)) => front(head, at)
      | _ => Dict.make()
      }
      {front: vars, body: String.slice(text, ~start=String.length(RegExp.Result.fullMatch(m)))}
    }
  }

// ---------------------------------------------------------------------------
// Resolution — substitute every `{{name}}` with its value from the first
// scope (most local first) that defines it, recursively, until no reference
// remains. Undefined variables and reference cycles fail loud.

type rec value =
  | Str(string)
  | Items(array<string>)
  | File(file)
  | Folder(folder)
  | Loop(loop)
  | Piped(piped)
and scope = {label: string, vars: dict<value>}
and file = {body: string, transform: string => string, front: scope, at: string}
and folder = {items: array<file>, each: string, at: string}
and loop = {source: string, each: string, join: string, template: option<string>, at: string}
and piped = {value: string, transform: string => string, at: string}

let reference = RegExp.fromString("\\{\\{\\s*([A-Za-z_][A-Za-z0-9_.-]*)\\s*\\}\\}", ~flags="g")

let labels = scopes => {
  let all = scopes->Array.map(s => s.label)->Array.join(", ")
  all == "" ? "no scopes" : all
}

let look = (scopes, name) => {
  let rec go = i =>
    if i >= Array.length(scopes) {
      None
    } else {
      switch Dict.get(Array.getUnsafe(scopes, i).vars, name) {
      | Some(v) => Some(v)
      | None => go(i + 1)
      }
    }
  go(0)
}

let rec expand = (text, scopes, active, at) =>
  String.replaceRegExpBy1Unsafe(text, reference, (
    ~match as ref,
    ~group1 as name,
    ~offset as _,
    ~input as _,
  ) => {
    let seen = Array.indexOf(active, name)
    if seen >= 0 {
      fail(`Variable cycle in ${at}: ${[...Array.slice(active, ~start=seen), name]->Array.join(" -> ")}`)
    } else {
      switch look(scopes, name) {
      | None => fail(`Undefined variable ${ref} in ${at} (searched: ${labels(scopes)})`)
      | Some(v) => grow(v, scopes, [...active, name], at)
      }
    }
  })
and grow = (v, scopes, active, at) =>
  switch v {
  | Str(s) => expand(s, scopes, active, at)
  | Items(items) => items->Array.map(item => expand(item, scopes, active, at))->Array.join("")
  | Loop(l) => loop(l, scopes, active)
  | Piped(p) => p.transform(expand(p.value, scopes, active, p.at))
  | Folder(f) =>
    f.items
    ->Array.map(item =>
      expand(
        f.each,
        [item.front, {label: f.at, vars: Dict.fromArray([("body", File(item))])}, ...scopes],
        active,
        f.at,
      )
    )
    ->Array.join("\n")
  | File(f) => f.transform(expand(f.body, [f.front, ...scopes], active, f.at))
  }
and loop = (l, scopes, active) =>
  switch look(scopes, l.source) {
  | None => fail(`Undefined list "${l.source}" in ${l.at} (searched: ${labels(scopes)})`)
  | Some(Items(items)) =>
    if Array.length(items) == 0 {
      ""
    } else {
      let body =
        items
        ->Array.map(item =>
          expand(
            l.each,
            [{label: `${l.at} item`, vars: Dict.fromArray([("item", Str(item))])}, ...scopes],
            active,
            l.at,
          )
        )
        ->Array.join(l.join)
      switch l.template {
      | None => body
      | Some(template) =>
        expand(
          template,
          [{label: `${l.at} template`, vars: Dict.fromArray([("body", Str(body))])}, ...scopes],
          active,
          l.at,
        )
      }
    }
  | Some(_) => fail(`${l.at}: "${l.source}" must resolve to a scalar list`)
  }

// ---------------------------------------------------------------------------
// FileSystem — the only door to the outside world.

type filesystem = {
  readFile: string => promise<string>,
  writeFile: (string, string) => promise<unit>,
  copy: (string, string) => promise<unit>,
  exists: string => promise<bool>,
  glob: string => promise<array<string>>,
  listFiles: string => promise<array<string>>,
}

type transform = string => string

let defaults: dict<transform> = Dict.fromArray([
  ("md", text => Md.parse(text, {sync: false})),
  ("none", text => text),
])

// In-memory FileSystem seeded from a name -> content mapping. Used by tests.
let makeMemoryFileSystem = (seed: option<dict<string>>): filesystem => {
  let files = Dict.copy(seed->Option.getOr(Dict.make()))
  let sorted = keys => keys->Array.toSorted(String.compare)
  {
    readFile: async path =>
      switch Dict.get(files, path) {
      | Some(content) => content
      | None => fail(`File not found: ${path}`)
      },
    writeFile: async (path, content) => Dict.set(files, path, content),
    copy: async (source, output) =>
      switch Dict.get(files, source) {
      | Some(content) => Dict.set(files, output, content)
      | None =>
        let prefix = `${source}/`
        let hits = Dict.toArray(files)->Array.filter(((path, _)) => String.startsWith(path, prefix))
        if Array.length(hits) == 0 {
          fail(`File not found: ${source}`)
        }
        hits->Array.forEach(((path, content)) =>
          Dict.set(files, `${output}/${String.slice(path, ~start=String.length(prefix))}`, content)
        )
      },
    exists: async path =>
      switch Dict.get(files, path) {
      | Some(_) => true
      | None => Dict.keysToArray(files)->Array.some(f => String.startsWith(f, `${path}/`))
      },
    glob: async pattern => Dict.keysToArray(files)->Array.filter(matcher(pattern))->sorted,
    listFiles: async dir => {
      let prefix = dir == "" ? "" : `${dir}/`
      Dict.keysToArray(files)
      ->Array.filter(p =>
        String.startsWith(p, prefix) && !String.includes(String.slice(p, ~start=String.length(prefix)), "/")
      )
      ->Array.map(p => String.slice(p, ~start=String.length(prefix)))
      ->sorted
    },
  }
}

// ---------------------------------------------------------------------------
// Node FileSystem — every node builtin loads lazily through dynamic import,
// so this module stays environment-neutral.

type dirent
@send external isFile: dirent => bool = "isFile"
@get external dname: dirent => string = "name"
@get external parent: dirent => string = "parentPath"

type ropts = {recursive: bool}
type lopts = {withFileTypes: bool, recursive: bool}
type fsmod = {
  readFile: (string, string) => promise<string>,
  writeFile: (string, string, string) => promise<unit>,
  mkdir: (string, ropts) => promise<unit>,
  cp: (string, string, ropts) => promise<unit>,
  access: string => promise<unit>,
  readdir: (string, lopts) => promise<array<dirent>>,
}
type urlmod = {fileURLToPath: unknown => string}

@scope("process") @val external cwd: unit => string = "cwd"
let import_: string => promise<'a> = %raw(`(name) => import(name)`)

// Node-backed FileSystem rooted at a path string or file:// URL (default: the
// current working directory). Creates parent directories on write.
let nodeFs = (root: option<string>): filesystem => {
  let cache: ref<option<promise<(fsmod, string)>>> = ref(None)
  let mods = () =>
    switch cache.contents {
    | Some(loaded) => loaded
    | None =>
      let loaded = (
        async () => {
          let fs: fsmod = await import_("node:fs/promises")
          let base = switch root {
          | None => cwd()
          | Some(r) =>
            if Type.typeof(r) == #string {
              String.startsWith(r, "/") ? r : join(cwd(), r)
            } else {
              let url: urlmod = await import_("node:url")
              url.fileURLToPath(magic(r))
            }
          }
          (fs, base)
        }
      )()
      cache.contents = Some(loaded)
      loaded
    }
  let absolute = (base, path) => String.startsWith(path, "/") ? path : join(base, path)
  {
    readFile: async path => {
      let (fs, base) = await mods()
      await fs.readFile(absolute(base, path), "utf8")
    },
    writeFile: async (path, content) => {
      let (fs, base) = await mods()
      let file = absolute(base, path)
      await fs.mkdir(dirname(file), {recursive: true})
      await fs.writeFile(file, content, "utf8")
    },
    copy: async (source, output) => {
      let (fs, base) = await mods()
      let target = absolute(base, output)
      await fs.mkdir(dirname(target), {recursive: true})
      await fs.cp(absolute(base, source), target, {recursive: true})
    },
    exists: async path => {
      let (fs, base) = await mods()
      try {
        await fs.access(absolute(base, path))
        true
      } catch {
      | _ => false
      }
    },
    glob: async pattern => {
      let (fs, base) = await mods()
      let entries = try {
        await fs.readdir(base, {withFileTypes: true, recursive: true})
      } catch {
      | _ => []
      }
      entries
      ->Array.filter(isFile(_))
      ->Array.map(e =>
        String.replaceRegExp(
          String.slice(`${parent(e)}/${dname(e)}`, ~start=String.length(base) + 1),
          slashes,
          "/",
        )
      )
      ->Array.filter(matcher(pattern))
      ->Array.toSorted(String.compare)
    },
    listFiles: async dir => {
      let (fs, base) = await mods()
      let entries = try {
        await fs.readdir(absolute(base, dir), {withFileTypes: true, recursive: false})
      } catch {
      | _ => []
      }
      entries->Array.filter(isFile(_))->Array.map(dname(_))->Array.toSorted(String.compare)
    },
  }
}

// ---------------------------------------------------------------------------
// Run — load a config chain, build every entry.

// Only the plain string vars of a block — the scopes file paths resolve in.
let strings = vars => {
  let out = Dict.make()
  Dict.toArray(vars)->Array.forEach(((name, v)) =>
    switch v {
    | Scalar(s) => Dict.set(out, name, Str(s))
    | _ => ()
    }
  )
  out
}

let lift = front =>
  front->Dict.mapValues(d =>
    switch d {
    | One(s) => Str(s)
    | Many(a) => Items(a)
    }
  )

let infer = path =>
  if String.endsWith(path, ".md") || String.endsWith(path, ".markdown") {
    Some("md")
  } else if String.endsWith(path, ".html") || String.endsWith(path, ".htm") {
    Some("none")
  } else {
    None
  }

// Read the config at `entry` and execute every build entry through `fs`.
let exec = async (fs: filesystem, entry, transforms: dict<transform>) => {
  // Per-run cache: each content file is read and frontmatter-split exactly
  // once, however many vars or build entries reference it.
  let cache: dict<promise<parsed>> = Dict.make()

  let named = (name, at) =>
    switch Dict.get(transforms, name) {
    | Some(t) => t
    | None =>
      fail(`${at}: unknown transform "${name}" (available: ${Dict.keysToArray(transforms)->Array.join(", ")})`)
    }

  let parsed = (path, at) =>
    switch Dict.get(cache, path) {
    | Some(hit) => hit
    | None =>
      let loading = (
        async () => {
          if !(await fs.exists(path)) {
            fail(`Content file not found: ${path} (declared at ${at})`)
          }
          split(await fs.readFile(path), path)
        }
      )()
      Dict.set(cache, path, loading)
      loading
    }

  // Load one content file; an explicit transform overrides the inference.
  let content = async (explicit, path, at) => {
    let {front, body} = await parsed(path, at)
    switch explicit->Option.orElse(infer(path)) {
    | None =>
      fail(
        `${at}: cannot infer a transform for ${path} — set "transform" (available: ${Dict.keysToArray(
            transforms,
          )->Array.join(", ")})`,
      )
    | Some(name) =>
      let c: file = {
        body,
        transform: named(name, at),
        front: {label: `frontmatter (${path})`, vars: lift(front)},
        at: `file ${path}`,
      }
      c
    }
  }

  // Load a dir var: list the folder, filter by glob, read each file.
  let folder = async (d: dirv, at, paths) => {
    let dir = expand(d.dir, paths, [], `${at} dir`)
    let glob = d.glob->Option.getOr("*.md")
    let names = (await fs.listFiles(dir))->Array.filter(matcher(glob))
    if Array.length(names) == 0 {
      fail(`No files matching "${glob}" in ${dir} (declared at ${at})`)
    }
    let items = await Promise.all(names->Array.map(name => content(d.transform, join(dir, name), at)))
    let f: folder = {items, each: d.each->Option.getOr("{{body}}"), at: `dir ${dir} (${at})`}
    f
  }

  // Load one `var` block into scopes: the vars themselves, then — less local,
  // so explicit vars win — the frontmatter exported by its file vars. Two
  // files exporting the same name is a conflict; fail loud.
  let scopes = async (vars: dict<varv>, label, paths) => {
    let loaded: dict<value> = Dict.make()
    let exported: dict<value> = Dict.make()
    let owners: dict<string> = Dict.make()
    await seq(Dict.toArray(vars), 0, async ((name, v)) => {
      let at = `${label}.${name}`
      switch v {
      | Scalar(s) => Dict.set(loaded, name, Str(s))
      | Scalars(a) => Dict.set(loaded, name, Items(a))
      | PipeV(p) => Dict.set(loaded, name, Piped({value: p.value, transform: named(p.transform, at), at}))
      | ListV(l) =>
        Dict.set(
          loaded,
          name,
          Loop({source: l.list, each: l.each, join: l.join->Option.getOr(""), template: l.template, at}),
        )
      | DirV(d) => Dict.set(loaded, name, Folder(await folder(d, at, paths)))
      | FileV(f) =>
        let path = expand(f.file, paths, [], `${at} file`)
        let c = await content(f.transform, path, at)
        Dict.set(loaded, name, File(c))
        // Dir file frontmatter stays local to each item — 8 chapters would
        // conflict on `title` — so only file vars export theirs.
        Dict.toArray(c.front.vars)->Array.forEach(((fname, fv)) => {
          switch Dict.get(owners, fname) {
          | Some(owner) if owner != path =>
            fail(`Frontmatter conflict in ${label}: "${fname}" defined by both ${owner} and ${path}`)
          | _ => ()
          }
          Dict.set(owners, fname, path)
          Dict.set(exported, fname, fv)
        })
      }
    })
    let head: scope = {label, vars: loaded}
    Array.length(Dict.keysToArray(exported)) > 0
      ? [head, {label: `frontmatter (${label})`, vars: exported}]
      : [head]
  }

  // Load the entry config and its `base` chain, entry (most local) first.
  let rec chain = async (path, visited, from) => {
    if Array.includes(visited, path) {
      fail(`Base config cycle: ${[...visited, path]->Array.join(" -> ")}`)
    }
    if !(await fs.exists(path)) {
      fail(`Config not found: ${path}${from == "" ? "" : ` (base of ${from})`}`)
    }
    let config = parse(await fs.readFile(path), path)
    let rest = switch config.base {
    | Some(base) => await chain(base, [...visited, path], path)
    | None => []
    }
    [(path, config), ...rest]
  }

  let emit = async (b: buildv, globals, paths, at) => {
    let label = `${at}.var`
    let local = [{label, vars: strings(b.vars)}, ...paths]
    let all = [...await scopes(b.vars, label, local), ...globals]
    let finish = async (v, all) => {
      let output = expand(b.output, all, [], `${at} output`)
      await fs.writeFile(output, grow(v, all, [], `${at} input`))
    }
    switch b.input {
    | Copy(path) =>
      let source = expand(path, local, [], `${at} input copy`)
      if !(await fs.exists(source)) {
        fail(`Copy source not found: ${source} (declared at ${at} input)`)
      }
      await fs.copy(source, expand(b.output, all, [], `${at} output`))
    | Text(t) => await finish(Str(t), all)
    | DirI(d) => await finish(Folder(await folder(d, `${at} input`, local)), all)
    | FileI(f) =>
      // A file input exports its frontmatter as the least local scope —
      // usable in the output path — mirroring file vars.
      let path = expand(f.file, local, [], `${at} input file`)
      let c = await content(f.transform, path, `${at} input`)
      await finish(File(c), [...all, c.front])
    }
  }

  // File paths may contain `{{refs}}` (already anchored at parse time). They
  // resolve against string vars only: frontmatter and file bodies are not
  // known until files load, so they cannot shape a path.
  let links = await chain(entry, [], "")
  let paths = links->Array.map(((path, config)) => {label: `var (${path})`, vars: strings(config.vars)})
  let globals: array<scope> = []
  await seq(links, 0, async ((path, config)) => {
    let loaded = await scopes(config.vars, `var (${path})`, paths)
    loaded->Array.forEach(s => Array.push(globals, s))
  })
  let (_, first) = Array.getUnsafe(links, 0)
  let _ = await Promise.all(first.build->Array.mapWithIndex((b, i) => emit(b, globals, paths, `build[${Int.toString(i)}]`)))
}

type runOptions = {
  glob: string,
  fs?: filesystem,
  transform?: dict<transform>,
}

// Discover and run all matching entry configs concurrently.
let run = async (options: runOptions) => {
  let fs = switch options.fs {
  | Some(fs) => fs
  | None => nodeFs(None)
  }
  let configs = await fs.glob(options.glob)
  if Array.length(configs) == 0 {
    fail(`No config files match "${options.glob}"`)
  }
  let transforms = Dict.assign(Dict.copy(defaults), options.transform->Option.getOr(Dict.make()))
  let _ = await Promise.all(
    configs->Array.toSorted(String.compare)->Array.map(config => exec(fs, config, transforms)),
  )
}
