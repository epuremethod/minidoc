// minidoc — a small documentation website generator, built on tilia.
//
// A context is a dict of templates, carved with tilia: every var is a lazy,
// cached, dependency-tracked computed. A child context re-hosts its parent's
// *templates* (own wins), so inherited templates re-resolve against local
// overrides — you inherit formulas, not values.

open Schema
open Tilia

external magic: 'a => 'b = "%identity"

module Md = {
  type opts = {@as("async") sync: bool}
  @module("marked") @scope("marked") external parse: (string, opts) => string = "parse"
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
  listDirs: string => promise<array<string>>,
}

type transform = string => string

let defaults: dict<transform> = Dict.fromArray([
  ("md", text => Md.parse(text, {sync: false})),
  ("none", text => text),
])

// ---------------------------------------------------------------------------
// Rendering — carved contexts.

/** A loaded content file: frontmatter split off, transform resolved. `pad`
 counts the blank lines standing in for the frontmatter at the top of `body`. */
type content = {
  body: string,
  transform: transform,
  front: dict<data>,
  at: string,
  pad: int,
  path: string,
}

/** A loaded var, ready to evaluate in a context. */
type rec lvar =
  | T(string) // template scalar
  | L(array<string>) // list of template scalars
  | V(data) // pre-rendered value — no further expansion
  | F(content, option<(string, string)>) // file, wrapper template and its site
  | D(array<content>, string, string) // dir items, each template, site
  | G(array<folder>, string, string) // dirs items, each template, site
  | R(listv, string) // list renderer, site
  | P(string, transform, string) // template, transform, site

/** A `dirs` item: its render site and its own templates. */
and folder = {where: string, lvars: dict<lvar>}

/** One context: a carve of every template visible to it. `inline` renders
 errors as boxes in the output instead of aborting. */
type ctx = {lvars: dict<lvar>, vars: dict<data>, get: string => option<data>, inline: bool}

// A backtick-quoted name is an escape: `{{`name`}}` renders as the literal
// reference, unevaluated and spaced exactly as written.
let reference = RegExp.fromString(
  "\\{\\{\\s*(`?)([A-Za-z_][A-Za-z0-9_.-]*)\\1\\s*\\}\\}",
  ~flags="g",
)

// The quoting backticks of an escape. A name can never contain one, so the
// only backticks inside a matched reference are the two quotes.
let backtick = RegExp.fromString("`", ~flags="g")

// Names currently being rendered: a repeat is a cycle, detected before the
// re-entrant read so the error propagates instead of looping.
let stack: ref<array<string>> = ref([])

// The first cycle found in a render site. Tilia re-runs derived values after
// an exception with the stack left mid-flight, so a later detection reports a
// phantom path (`b -> b`); rethrowing the first keeps the real one.
let cycle: ref<option<string>> = ref(None)

// Decorate an error with its render site; the innermost site wins.
let rawSite: (string, unit => unknown) => unknown = %raw(`(at, fn) => {
  try { return fn() } catch (e) {
    if (e && e.message && !e.minidocSited) {
      e.minidocSited = true
      e.message = e.message.startsWith("Variable cycle:")
        ? "Variable cycle in " + at + ":" + e.message.slice(15)
        : e.message + " in " + at
    }
    throw e
  }
}`)
let site = (at, fn: unit => 'a): 'a => magic(rawSite(at, magic(fn)))

// A failed render surfaces as an error box at its place in the page; the
// cycle stack unwinds to the box boundary so sibling renders keep going.
let rawBoxed: (ref<array<string>>, bool, unit => string) => string = %raw(`(stack, inline, fn) => {
  if (!inline) return fn()
  const active = stack.contents
  try { return fn() } catch (e) {
    stack.contents = active
    const message = String((e && e.message) || e)
    console.error("minidoc: " + message)
    const text = message.replace(/&/g, "&amp;").replace(/</g, "&lt;")
    return '<div class="minidoc-error" style="border:1px solid #c00;background:rgba(255,0,0,.04);padding:.5em .75em;font-family:monospace;white-space:pre-wrap;">' + text + '</div>'
  }
}`)
let boxed = (inline, fn: unit => string): string => rawBoxed(stack, inline, fn)

// Multi-line templates get a line number; one-liners locate themselves.
let lined = (template, offset) =>
  String.includes(template, "\n")
    ? ` at line ${Int.toString(
          Array.length(String.split(String.slice(template, ~start=0, ~end=offset), "\n")),
        )}`
    : ""

// Remove the frontmatter stand-in newlines an identity-like transform kept.
let unpad = (text, pad) => {
  let rec go = i => i < pad && String.charAt(text, i) == "\n" ? go(i + 1) : i
  String.slice(text, ~start=go(0))
}

/** Child templates shadow the parent's. */
let over = (parent, own) => Dict.assign(Dict.copy(parent), own)

let data = front =>
  front->Dict.mapValues(d =>
    switch d {
    | One(s) => T(s)
    | Many(a) => L(a)
    }
  )

let basename = path => String.slice(path, ~start=String.lastIndexOf(path, "/") + 1)

/** A content file's own name, for templates that would otherwise need a
 `slug` in every frontmatter. Pre-rendered: a file name is never a template. */
let naming = (c: content) => {
  let name = basename(c.path)
  let dot = String.lastIndexOf(name, ".")
  let stem = dot > 0 ? String.slice(name, ~start=0, ~end=dot) : name
  Dict.fromArray([
    ("file.name", V(One(name))),
    ("file.stem", V(One(stem))),
    ("file.dir", V(One(basename(dirname(c.path))))),
  ])
}

let rec make = (inline, lvars: dict<lvar>): ctx =>
  carve(({derived}) => {
    inline,
    lvars,
    vars: lvars->Dict.mapValues(lv => derived((self: ctx) => eval(lv, self))),
    get: derived((self: ctx) => name => Dict.get(self.vars, name)),
  })
and sub = (self: ctx, extra: dict<lvar>) => make(self.inline, over(self.lvars, extra))
and eval = (lv, self: ctx) =>
  switch lv {
  | T(s) => One(render(s, self.get))
  | L(items) => Many(items->Array.map(render(_, self.get)))
  | V(d) => d
  | P(value, transform, at) =>
    One(boxed(self.inline, () => site(at, () => transform(render(value, self.get)))))
  | F(c, wrap) =>
    One(
      boxed(self.inline, () =>
        site(c.at, () => {
          let front = sub(self, data(c.front))
          let body = unpad(c.transform(render(c.body, front.get)), c.pad)
          // Like a `list` wrapper: an empty body renders nothing, wrapper included.
          switch wrap {
          | Some((template, at)) if String.trim(body) != "" =>
            site(at, () => render(template, sub(front, Dict.fromArray([("body", V(One(body)))])).get))
          | Some(_) => ""
          | None => body
          }
        })
      ),
    )
  | D(items, each, at) =>
    One(
      site(at, () =>
        items
        ->Array.map(c =>
          boxed(self.inline, () =>
            site(at, () => {
              let front = sub(self, over(naming(c), data(c.front)))
              let body = unpad(c.transform(site(c.at, () => render(c.body, front.get))), c.pad)
              render(each, sub(front, Dict.fromArray([("body", V(One(body)))])).get)
            })
          )
        )
        ->Array.join("\n")
      ),
    )
  | G(items, each, at) =>
    One(
      site(at, () =>
        items
        ->Array.map(item =>
          boxed(self.inline, () => site(item.where, () => render(each, sub(self, item.lvars).get)))
        )
        ->Array.join("\n")
      ),
    )
  | R(l, at) =>
    One(
      boxed(self.inline, () =>
        site(at, () =>
          switch self.get(l.list) {
          | None => fail(`Undefined variable {{${l.list}}}`)
          | Some(One(_)) => fail(`"${l.list}" must resolve to a scalar list`)
          | Some(Many(items)) =>
            if Array.length(items) == 0 {
              ""
            } else {
              let one = (name, value, template) =>
                render(template, sub(self, Dict.fromArray([(name, V(One(value)))])).get)
              let body =
                items
                ->Array.map(item => one("item", item, l.each))
                ->Array.join(l.join->Option.getOr(""))
              switch l.template {
              | Some(template) => one("body", body, template)
              | None => body
              }
            }
          }
        )
      ),
    )
  }
and render = (template, get) =>
  template->String.replaceRegExpBy2Unsafe(reference, (
    ~match as ref,
    ~group1 as quote,
    ~group2 as name,
    ~offset,
    ~input,
  ) =>
    if quote != "" {
      // Drop the quotes and keep the rest of the match exactly as written, so
      // spacing survives: `{{ `name` }}` stays `{{ name }}`. An escape is a
      // passthrough, and a passthrough that reformats its input is a rewrite.
      String.replaceRegExp(ref, backtick, "")
    } else {
      let active = stack.contents
      if Array.includes(active, name) {
        let from = Array.indexOf(active, name)
        let path = switch cycle.contents {
        | Some(path) => path
        | None => [...Array.slice(active, ~start=from), name]->Array.join(" -> ")
        }
        cycle := Some(path)
        fail(`Variable cycle: ${path}`)
      }
      stack := [...active, name]
      let out = switch get(name) {
      | Some(One(s)) => s
      | Some(Many(a)) => a->Array.join("")
      | None => fail(`Undefined variable ${ref}${lined(input, offset)}`)
      }
      stack := active
      out
    }
  )

/** A top-level render site: fresh cycle stack, site-labeled errors. */
let top = (at, fn: unit => 'a): 'a => {
  stack := []
  cycle := None
  site(at, fn)
}

// ---------------------------------------------------------------------------
// Paths and frontmatter.

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

// Collapse `.` and `..` so one output reached through two spellings shares a
// key. Leading `..` that cannot collapse is kept.
let normalize = path => {
  let rooted = String.startsWith(path, "/")
  let parts = String.split(path, "/")->Array.reduce([], (acc, s) =>
    switch (s, Array.at(acc, -1)) {
    | ("" | ".", _) => acc
    | ("..", Some(prev)) if prev != ".." => Array.slice(acc, ~start=0, ~end=Array.length(acc) - 1)
    | ("..", _) if rooted => acc
    | (s, _) => [...acc, s]
    }
  )
  (rooted ? "/" : "") ++ Array.join(parts, "/")
}

let matter = RegExp.fromString("^---\\n(?:([\\s\\S]*?)\\n)?---(?:\\n|$)")

type page = {front: dict<data>, body: string, pad: int}

let split = (text, at) =>
  if !String.startsWith(text, "---\n") {
    {front: Dict.make(), body: text, pad: 0}
  } else {
    switch RegExp.exec(matter, text) {
    | None => fail(`${at}: unterminated frontmatter (missing closing "---" line)`)
    | Some(m) =>
      let vars = switch m->RegExp.Result.matches->Array.get(0) {
      | Some(Some(head)) => front(head, at)
      | _ => Dict.make()
      }
      // Blank lines stand in for the frontmatter so the body keeps its place
      // in the document: line numbers in errors — ours and the transforms' —
      // point at the real file line.
      let full = RegExp.Result.fullMatch(m)
      let pad = Array.length(String.split(full, "\n")) - 1
      {
        front: vars,
        body: String.repeat("\n", pad) ++ String.slice(text, ~start=String.length(full)),
        pad,
      }
    }
  }

let infer = path =>
  if String.endsWith(path, ".md") || String.endsWith(path, ".markdown") {
    Some("md")
  } else if String.endsWith(path, ".html") || String.endsWith(path, ".htm") {
    Some("none")
  } else {
    None
  }

let rec seq = async (xs, i, fn) =>
  if i < Array.length(xs) {
    await fn(Array.getUnsafe(xs, i))
    await seq(xs, i + 1, fn)
  }

// ---------------------------------------------------------------------------
// Loading — read configs and content up front; contexts are carved after.

// Scalar-only lookup for `{{refs}}` inside declared paths, which resolve
// before any content loads and so can never depend on it.
let strs = (vars: dict<varv>, parent) => {
  let rec get = name =>
    switch Dict.get(vars, name) {
    | Some(Scalar(s)) => Some(One(render(s, get)))
    | _ => parent(name)
    }
  get
}

let named = (transforms, name, at) =>
  switch Dict.get(transforms, name) {
  | Some(t) => t
  | None =>
    fail(`${at}: unknown transform "${name}" (available: ${Dict.keysToArray(transforms)->Array.join(", ")})`)
  }

let content = async (fs: filesystem, transforms, path, explicit, at) => {
  if !(await fs.exists(path)) {
    fail(`Content file not found: ${path} (declared at ${at})`)
  }
  let {front, body, pad} = split(await fs.readFile(path), path)
  let name = switch explicit->Option.orElse(infer(path)) {
  | Some(name) => name
  | None =>
    fail(
      `${at}: cannot infer a transform for ${path} — set "transform" (available: ${Dict.keysToArray(
          transforms,
        )->Array.join(", ")})`,
    )
  }
  {body, transform: named(transforms, name, at), front, at: `file ${path}`, pad, path}
}

let ordered = (names, order) => order == Some(Desc) ? Array.toReversed(names) : names

// Every file below `dir`, as paths relative to it.
let rec walk = async (fs: filesystem, dir, prefix) => {
  let here = prefix == "" ? dir : join(dir, prefix)
  let files = (await fs.listFiles(here))->Array.map(join(prefix, _))
  let nested = await Promise.all((await fs.listDirs(here))->Array.map(d => walk(fs, dir, join(prefix, d))))
  Array.concat(files, Array.flat(nested))
}

/** The files a `dir` var or a `pages` entry selects, in path order (`order:
 desc` reverses it). A glob with a `/` or a `**` reaches into subfolders. An
 empty match fails loud unless the source is `optional`. */
let listing = async (fs: filesystem, transforms, pget, src: source, at) => {
  let dir = top(`${at} dir`, () => render(src.dir, pget))
  let glob = src.glob->Option.getOr("*.md")
  let deep = String.includes(glob, "/") || String.includes(glob, "**")
  let names =
    (deep ? await walk(fs, dir, "") : await fs.listFiles(dir))
    ->Array.filter(matcher(glob))
    ->Array.toSorted(String.compare)
    ->ordered(src.order)
  if Array.length(names) == 0 && !(src.optional->Option.getOr(false)) {
    fail(`No files matching "${glob}" in ${dir} (declared at ${at})`)
  }
  (dir, await Promise.all(names->Array.map(n => content(fs, transforms, join(dir, n), src.transform, at))))
}

/** Load one `var` block: its lvars plus the frontmatter its file vars export. */
let rec load = async (fs: filesystem, transforms: dict<transform>, pget, label, vars: dict<varv>) => {
  let out: dict<lvar> = Dict.make()
  let exports: dict<lvar> = Dict.make()
  let owners: dict<string> = Dict.make()
  await seq(Dict.toArray(vars), 0, async ((name, v)) => {
    let at = `${label}.${name}`
    switch v {
    | Scalar(s) => Dict.set(out, name, T(s))
    | Scalars(a) => Dict.set(out, name, L(a))
    | ListV(l) => Dict.set(out, name, R(l, at))
    | PipeV(p) => Dict.set(out, name, P(p.value, named(transforms, p.transform, at), at))
    | FileV(f) if f.optional == Some(true) && !(await fs.exists(top(`${at} file`, () => render(f.file, pget)))) =>
      Dict.set(out, name, V(One("")))
    | FileV(f) =>
      let path = top(`${at} file`, () => render(f.file, pget))
      let c = await content(fs, transforms, path, f.transform, at)
      // Only file vars export their frontmatter — dir items would conflict
      // on names like `title`, so theirs stays local to each item.
      Dict.toArray(data(c.front))->Array.forEach(((fname, lv)) => {
        switch Dict.get(owners, fname) {
        | Some(owner) if owner != path =>
          fail(`Frontmatter conflict in ${label}: "${fname}" defined by both ${owner} and ${path}`)
        | _ => ()
        }
        Dict.set(owners, fname, path)
        Dict.set(exports, fname, lv)
      })
      Dict.set(out, name, F(c, f.template->Option.map(t => (t, `${at} template`))))
    | DirV(d) =>
      let src = {dir: d.dir, glob: d.glob, transform: d.transform, optional: d.optional, order: d.order}
      let (dir, items) = await listing(fs, transforms, pget, src, at)
      Dict.set(out, name, D(items, d.each->Option.getOr("{{body}}"), `dir ${dir} (${at})`))
    | DirsV(d) =>
      let root = top(`${at} dirs`, () => render(d.dirs, pget))
      let names = (await fs.listDirs(root))->Array.toSorted(String.compare)->ordered(d.order)
      if Array.length(names) == 0 && !(d.optional->Option.getOr(false)) {
        fail(`No folders in ${root} (declared at ${at})`)
      }
      // Each subfolder loads the item vars as its own `var` block: paths
      // anchor at the subfolder, and file frontmatter stays in the item.
      let items = await Promise.all(
        names->Array.map(async n => {
          let dir = join(root, n)
          let fget = key => key == "folder.name" ? Some(One(n)) : pget(key)
          let vars = d.vars->Option.getOr(Dict.make())->Dict.mapValues(anchor(dir, ...))
          let (own, exports) = await load(fs, transforms, strs(vars, fget), `${at}.var`, vars)
          let lvars = over(over(Dict.fromArray([("folder.name", V(One(n)))]), exports), own)
          {where: `folder ${dir} (${at})`, lvars}
        }),
      )
      Dict.set(out, name, G(items, d.each, `dirs ${root} (${at})`))
    }
  })
  (out, exports)
}

// The entry config and its base chain, base-most first: a base contributes
// templates the child re-hosts (and may shadow) in its own context.
let rec chain = async (fs: filesystem, path, visited, from) => {
  if Array.includes(visited, path) {
    fail(`Base config cycle: ${[...visited, path]->Array.join(" -> ")}`)
  }
  if !(await fs.exists(path)) {
    fail(`Config not found: ${path}${from == "" ? "" : ` (base of ${from})`}`)
  }
  let config = parse(await fs.readFile(path), path)
  switch config.base {
  | Some(base) => Array.concat(await chain(fs, base, [...visited, path], path), [config])
  | None => [config]
  }
}

/** One file a build entry writes; `by` names the entry (and page) for errors. */
type job = {output: string, by: string, copy: bool, write: unit => promise<unit>}

/** Read the config at `entry` and execute every build entry through `fs`. */
let exec = async (fs: filesystem, transforms, inline, entry) => {
  let configs = await chain(fs, entry, [], "")
  let pget = configs->Array.reduce(_ => None, (parent, c) => strs(c.vars, parent))
  let rec grow = async (acc, i) =>
    if i >= Array.length(configs) {
      acc
    } else {
      let (own, exports) = await load(fs, transforms, pget, `var (${entry})`, Array.getUnsafe(configs, i).vars)
      await grow(over(over(acc, exports), own), i + 1)
    }
  let shared = await grow(Dict.make(), 0)
  let last = Array.getUnsafe(configs, Array.length(configs) - 1)
  // Every output path resolves before anything is written, so a collision
  // fails loud with nothing half-built.
  let plans = await Promise.all(
    last.build->Array.mapWithIndex(async (b, i) => {
      let at = `build[${Int.toString(i)}]`
      let bpget = strs(b.vars, pget)
      let (own, exports) = await load(fs, transforms, bpget, `${at}.var`, b.vars)
      switch (b.input, b.pages) {
      | (Copy(_), Some(_)) => fail(`${at}: "pages" cannot be combined with a copy input`)
      | (Copy(path), None) =>
        let source = top(`${at} input copy`, () => render(path, bpget))
        if !(await fs.exists(source)) {
          fail(`Copy source not found: ${source} (declared at ${at} input)`)
        }
        let ctx = make(inline, over(over(shared, exports), own))
        let output = top(`${at} output`, () => render(b.output, ctx.get))
        [{output, by: at, copy: true, write: () => fs.copy(source, output)}]
      | (input, pages) =>
        // A file input contributes its frontmatter as the least local
        // templates — usable even in the output path.
        let (lv, front) = switch input {
        | FileI({optional: Some(_)}) | FileI({template: Some(_)}) =>
          fail(`${at} input: "optional" and "template" apply to file vars, not to a file input`)
        | FileI(f) =>
          let path = top(`${at} input file`, () => render(f.file, bpget))
          let (own, _) = await load(fs, transforms, bpget, at, Dict.fromArray([("input", FileV({...f, file: path}))]))
          switch Dict.get(own, "input") {
          | Some(F(c, wrap)) => (F(c, wrap), data(c.front))
          | _ => (T(""), Dict.make())
          }
        | DirI(d) =>
          let (own, _) = await load(fs, transforms, bpget, at, Dict.fromArray([("input", DirV(d))]))
          switch Dict.get(own, "input") {
          | Some(D(items, each, site)) => (D(items, each, site), Dict.make())
          | _ => (T(""), Dict.make())
          }
        | Text(t) => (T(t), Dict.make())
        | Copy(_) => (T(""), Dict.make())
        }
        let base = over(over(front, shared), exports)
        let job = (layer, page) => {
          let ctx = make(inline, over(over(base, layer), own))
          let output = top(`${at} output${page}`, () => render(b.output, ctx.get))
          let write = async () => {
            // Content errors can turn into boxes; output path errors never do —
            // a file cannot be written without a path.
            let out = boxed(inline, () =>
              switch top(`${at} input${page}`, () => eval(lv, ctx)) {
              | One(s) => s
              | Many(a) => a->Array.join("")
              }
            )
            await fs.writeFile(output, out)
          }
          {output, by: `${at}${page}`, copy: false, write}
        }
        switch pages {
        | None => [job(Dict.make(), "")]
        | Some(src) =>
          // One output per file. A page layers like a file var's frontmatter —
          // over the shared templates, under the entry's own vars — and hands
          // its rendered body over as `page`.
          let (_, items) = await listing(fs, transforms, bpget, src, `${at}.pages`)
          items->Array.map(c =>
            job(
              over(over(naming(c), data(c.front)), Dict.fromArray([("page", F(c, None))])),
              ` (page ${c.path})`,
            )
          )
        }
      }
    }),
  )
  let jobs = Array.flat(plans)
  // Copies may share a target directory (they merge); anything else sharing
  // an output would silently overwrite.
  let owners: dict<job> = Dict.make()
  jobs->Array.forEach(j => {
    let key = normalize(j.output)
    switch Dict.get(owners, key) {
    | Some(o) if !(o.copy && j.copy) =>
      fail(`Output path collision: ${key} is written by both ${o.by} and ${j.by}`)
    | _ => Dict.set(owners, key, j)
    }
  })
  let _ = await Promise.all(jobs->Array.map(j => j.write()))
}

// ---------------------------------------------------------------------------
// FileSystems.

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
    listDirs: async dir => {
      let prefix = dir == "" ? "" : `${dir}/`
      let names: dict<unit> = Dict.make()
      Dict.keysToArray(files)->Array.forEach(p =>
        if String.startsWith(p, prefix) {
          let rest = String.slice(p, ~start=String.length(prefix))
          let slash = String.indexOf(rest, "/")
          if slash > 0 {
            Dict.set(names, String.slice(rest, ~start=0, ~end=slash), ())
          }
        }
      )
      Dict.keysToArray(names)->sorted
    },
  }
}

// Node FileSystem — every node builtin loads lazily through dynamic import,
// so this module stays environment-neutral.

type dirent
@send external isFile: dirent => bool = "isFile"
@send external isDirectory: dirent => bool = "isDirectory"
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
  // Collapse `.` and `..` so one target reached from two config dirs shares a key.
  let canonical = path =>
    "/" ++
    String.split(path, "/")
    ->Array.reduce([], (acc, s) =>
      switch s {
      | "" | "." => acc
      | ".." => Array.slice(acc, ~start=0, ~end=Array.length(acc) - 1)
      | s => [...acc, s]
      }
    )
    ->Array.join("/")
  let copying: dict<promise<unit>> = Dict.make()
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
      let target = canonical(absolute(base, output))
      // fs.cp races on a shared target (EEXIST on mkdir), so serialize per target.
      let previous = copying->Dict.get(target)->Option.getOr(Promise.resolve())
      let current = (
        async () => {
          try await previous catch {
          | _ => ()
          }
          await fs.mkdir(dirname(target), {recursive: true})
          await fs.cp(absolute(base, source), target, {recursive: true})
        }
      )()
      copying->Dict.set(target, current)
      await current
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
    listDirs: async dir => {
      let (fs, base) = await mods()
      let entries = try {
        await fs.readdir(absolute(base, dir), {withFileTypes: true, recursive: false})
      } catch {
      | _ => []
      }
      entries->Array.filter(isDirectory(_))->Array.map(dname(_))->Array.toSorted(String.compare)
    },
  }
}

// ---------------------------------------------------------------------------

type runOptions = {
  glob: string,
  fs?: filesystem,
  transform?: dict<transform>,
  inlineErrors?: bool,
}

// Discover and run all matching entry configs concurrently.
let run = async (options: runOptions) => {
  let inline = options.inlineErrors->Option.getOr(false)
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
    configs->Array.toSorted(String.compare)->Array.map(config => exec(fs, transforms, inline, config)),
  )
}

// ---------------------------------------------------------------------------
// Development — watch, rebuild, serve.

type watchOptions = {
  ...runOptions,
  /**
   Node script spawned for each rebuild. Without it `run` executes in this
   process, which cannot see an edited transformer: transforms arrive as
   closures, and no ESM cache hands back a module a file has changed under.
  */
  build?: string,
  /** Directory watched, recursively. Default: the current working directory. */
  root?: string,
  /** More paths watched alongside `root` — files or folders, inside it or not. */
  watch?: array<string>,
  /** Path segments never watched. Default: dist, node_modules, lib (and any dot-name). */
  ignore?: array<string>,
  /** Extensions that trigger a rebuild. Default: content, config, and script files. */
  extensions?: array<string>,
}

type devOptions = {
  ...watchOptions,
  /** Directory served, relative to `root`. Default: "dist". */
  serve?: string,
  /** A fixed port; without one, the port remembered in the entry config. */
  port?: int,
}

type watcher = Dev.stopper = {stop: unit => unit}
type server = Dev.running = {port: int, stop: unit => unit}

// The first config the glob matches: the one that declares this site, and so
// the one that remembers its port.
let entry = async (fs: filesystem, glob) =>
  switch (await fs.glob(glob))->Array.toSorted(String.compare)->Array.get(0) {
  | Some(path) => path
  | None => fail(`No config files match "${glob}"`)
  }

let watch = async (options: watchOptions) => {
  let root = options.root->Option.getOr(Dev.cwd())
  let rebuild = switch options.build {
  | Some(path) => () => Dev.script(path, root)
  | None =>
    () =>
      run({
        glob: options.glob,
        fs: ?options.fs,
        transform: ?options.transform,
        inlineErrors: ?options.inlineErrors,
      })
  }
  await Dev.watch(
    {root, watch: ?options.watch, ignore: ?options.ignore, extensions: ?options.extensions},
    rebuild,
  )
}

let dev = async (options: devOptions) => {
  let root = options.root->Option.getOr(Dev.cwd())
  let fs = switch options.fs {
  | Some(fs) => fs
  | None => nodeFs(None)
  }
  let rebuild = switch options.build {
  | Some(path) => () => Dev.script(path, root)
  | None =>
    () =>
      run({
        glob: options.glob,
        fs: ?options.fs,
        transform: ?options.transform,
        inlineErrors: options.inlineErrors->Option.getOr(true),
      })
  }
  await Dev.dev(
    {
      root,
      watch: ?options.watch,
      ignore: ?options.ignore,
      extensions: ?options.extensions,
      serve: ?options.serve,
      port: ?options.port,
    },
    {
      rebuild,
      readPort: async () => Schema.port(await fs.readFile(await entry(fs, options.glob))),
      writePort: async port => {
        let path = await entry(fs, options.glob)
        await fs.writeFile(path, Schema.withPort(await fs.readFile(path), port))
      },
    },
  )
}
