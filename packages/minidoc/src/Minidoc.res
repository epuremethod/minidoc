// minidoc — a small documentation website generator, built on tilia.
//
// A context is a tree of templates, carved with tilia: every var is a lazy,
// cached, dependency-tracked computed. A child context re-hosts its parent's
// *templates*, merged leaf by leaf (own wins), so inherited templates
// re-resolve against local overrides — you inherit formulas, not values.

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
// Rendering — carved contexts over merged trees.

/** Where a leaf was declared: the directory its paths anchor to, and the
 label errors name it by. */
type origin = {dir: string, label: string}

/** A loaded content file: frontmatter split off. `pad` counts the blank lines
 standing in for the frontmatter at the top of `body`. */
type rec content = {
  body: string,
  front: dict<node>,
  at: string,
  pad: int,
  path: string,
}

/** A merged var tree. A group is a plain namespace until it is read: then its
 keys decide what it renders as (`file`, `dir`, `dirs`, `list`, `value`). */
and node =
  | Leaf(string, origin) // template scalar
  | List(array<string>, origin) // list of template scalars
  | Group(dict<node>)
  | Fixed(data) // pre-rendered value — no further expansion
  | Body(content, transform) // a page's body, rendered in the page context

/** A settled read: its value, or the error it threw, rethrown as is. */
type outcome = {ok: bool, value: unknown}

/** Per-run I/O cache. Rendering is synchronous; a read it needs and does not
 have yet starts in `started` and the render stalls (see `Pending`). */
type env = {
  fs: filesystem,
  transforms: dict<transform>,
  cache: dict<outcome>,
  started: dict<promise<unit>>,
}

/** One context: a carve of every template visible to it. `inline` renders
 errors as boxes in the output instead of aborting. */
type rec ctx = {
  env: env,
  inline: bool,
  tree: dict<node>,
  vars: dict<data>,
  get: string => option<data>,
}

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

// A render that needs a read not done yet throws this marker. It carries no
// message, so sites never label it, and boxes never catch it: the whole
// render is retried once the reads land.
let pending: unit => 'a = %raw(`() => { throw { minidocPending: true } }`)

// `Some(fn())`, or `None` when it stalled on a pending read.
let attempt: (unit => 'a) => option<'a> = %raw(`(fn) => {
  try { return fn() } catch (e) { if (e && e.minidocPending) return undefined; throw e }
}`)

let capture: (unit => promise<unknown>) => promise<outcome> = %raw(`async (load) => {
  try { return { ok: true, value: await load() } } catch (e) { return { ok: false, value: e } }
}`)
let rethrow: unknown => 'a = %raw(`(e) => { throw e }`)

// An error whose message already names its site.
let loud: string => 'a = %raw(`(message) => {
  const e = new Error(message); e.minidocSited = true; throw e
}`)

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
    if (e && e.minidocPending) throw e
    const message = String((e && e.message) || e)
    console.error("minidoc: " + message)
    const text = message.replace(/&/g, "&amp;").replace(/</g, "&lt;")
    return '<div class="minidoc-error" style="border:1px solid #c00;background:rgba(255,0,0,.04);padding:.5em .75em;font-family:monospace;white-space:pre-wrap;">' + text + '</div>'
  }
}`)
let boxed = (inline, fn: unit => string): string => rawBoxed(stack, inline, fn)

/** `f` over every item; every item's pending reads start before it stalls. */
let all = (xs, f) => {
  let stalled = ref(false)
  let out = xs->Array.map(x =>
    switch attempt(() => f(x)) {
    | Some(v) => Some(v)
    | None =>
      stalled := true
      None
    }
  )
  if stalled.contents {
    pending()
  }
  out->Array.filterMap(v => v)
}

/** A cached read: its value, or a pending stall while it loads. A failed read
 rethrows its error wherever it is needed. */
let need = (env, key, load: unit => promise<'a>): 'a =>
  switch Dict.get(env.cache, key) {
  | Some({ok: true, value}) => magic(value)
  | Some({value}) => rethrow(value)
  | None =>
    if !Dict.has(env.started, key) {
      Dict.set(env.started, key, capture(magic(load))->Promise.thenResolve(o => Dict.set(env.cache, key, o)))
    }
    pending()
  }

/** Run a synchronous render until no read is pending. */
let rec settle = async (env, fn: unit => 'a): 'a =>
  switch attempt(fn) {
  | Some(v) => v
  | None =>
    let before = Dict.keysToArray(env.cache)->Array.length
    let _ = await Promise.all(Dict.valuesToArray(env.started))
    if Dict.keysToArray(env.cache)->Array.length == before {
      fail("minidoc: render stalled with no read pending")
    }
    await settle(env, fn)
  }

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

// ---------------------------------------------------------------------------
// Trees — as written, then merged.

/** A tree as written, dotted keys spelled out as nesting: `a.b: x` and
 `a: { b: x }` are the same var. Defining one leaf twice fails loud. */
let rec nodes = (trees: dict<tree>, origin): dict<node> => {
  let out = Dict.make()
  trees->Dict.forEachWithKey((t, key) => {
    let n = switch t {
    | Str(s) => Leaf(s, origin)
    | Strs(a) => List(a, origin)
    | Tree(d) => Group(nodes(d, origin))
    }
    place(out, String.split(key, "."), n, key, origin)
  })
  out
}
and place = (out, path, n, key, origin) => {
  let head = Array.getUnsafe(path, 0)
  let twice = () => fail(`${origin.label}: "${key}" is defined twice`)
  if Array.length(path) == 1 {
    switch (Dict.get(out, head), n) {
    | (None, n) => Dict.set(out, head, n)
    | (Some(Group(into)), Group(more)) =>
      more->Dict.forEachWithKey((m, k) => place(into, [k], m, `${key}.${k}`, origin))
    | _ => twice()
    }
  } else {
    let into = switch Dict.get(out, head) {
    | None =>
      let d = Dict.make()
      Dict.set(out, head, Group(d))
      d
    | Some(Group(d)) => d
    | Some(_) => twice()
    }
    place(into, Array.slice(path, ~start=1), n, key, origin)
  }
}

/** Deep merge: a child layer's leaves shadow the parent's one by one; groups
 merge key by key, so overriding `layouts.cv` keeps `layouts.letter`. */
let rec merge = (parent: dict<node>, own: dict<node>) => {
  let out = Dict.copy(parent)
  own->Dict.forEachWithKey((n, k) =>
    switch (Dict.get(out, k), n) {
    | (Some(Group(a)), Group(b)) => Dict.set(out, k, Group(merge(a, b)))
    | _ => Dict.set(out, k, n)
    }
  )
  out
}

/** The same tree, its paths anchored at `dir` and its errors labeled `label`. */
let rec reanchor = (tree: dict<node>, origin) =>
  tree->Dict.mapValues(n =>
    switch n {
    | Leaf(s, _) => Leaf(s, origin)
    | List(a, _) => List(a, origin)
    | Group(d) => Group(reanchor(d, origin))
    | n => n
    }
  )

/** Every node by its dotted path, groups included. */
let paths = tree => {
  let out = Dict.make()
  let rec go = (tree, prefix) =>
    tree->Dict.forEachWithKey((n, k) => {
      let p = prefix == "" ? k : `${prefix}.${k}`
      Dict.set(out, p, n)
      switch n {
      | Group(d) => go(d, p)
      | _ => ()
      }
    })
  go(tree, "")
  out
}

let fixed = s => Fixed(One(s))
let group = pairs => Group(Dict.fromArray(pairs))

let basename = path => String.slice(path, ~start=String.lastIndexOf(path, "/") + 1)

/** A content file's own name, for templates that would otherwise need a
 `slug` in every frontmatter. Pre-rendered: a file name is never a template. */
let naming = (c: content) => {
  let name = basename(c.path)
  let dot = String.lastIndexOf(name, ".")
  let stem = dot > 0 ? String.slice(name, ~start=0, ~end=dot) : name
  Dict.fromArray([
    (
      "file",
      group([("name", fixed(name)), ("stem", fixed(stem)), ("dir", fixed(basename(dirname(c.path))))]),
    ),
  ])
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

/** Split a content file. Its frontmatter's own paths anchor at its folder. */
let split = (text, path): content => {
  let at = `file ${path}`
  let parsed = if !String.startsWith(text, "---\n") {
    None
  } else {
    switch RegExp.exec(matter, text) {
    | None => fail(`${path}: unterminated frontmatter (missing closing "---" line)`)
    | Some(m) => Some(m)
    }
  }
  switch parsed {
  | None => {body: text, front: Dict.make(), at, pad: 0, path}
  | Some(m) =>
    let trees = switch m->RegExp.Result.matches->Array.get(0) {
    | Some(Some(head)) => front(head, path)
    | _ => Dict.make()
    }
    // Blank lines stand in for the frontmatter so the body keeps its place
    // in the document: line numbers in errors — ours and the transforms' —
    // point at the real file line.
    let full = RegExp.Result.fullMatch(m)
    let pad = Array.length(String.split(full, "\n")) - 1
    {
      body: String.repeat("\n", pad) ++ String.slice(text, ~start=String.length(full)),
      front: nodes(trees, {dir: dirname(path), label: at}),
      at,
      pad,
      path,
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

let named = (transforms, name, at) =>
  switch Dict.get(transforms, name) {
  | Some(t) => t
  | None =>
    fail(`${at}: unknown transform "${name}" (available: ${Dict.keysToArray(transforms)->Array.join(", ")})`)
  }

/** The transform of `path`: the explicit one, else inferred from its extension. */
let transformOf = (transforms, path, explicit, at) =>
  switch explicit->Option.orElse(infer(path)) {
  | Some(name) => named(transforms, name, at)
  | None =>
    fail(
      `${at}: cannot infer a transform for ${path} — set "transform" (available: ${Dict.keysToArray(
          transforms,
        )->Array.join(", ")})`,
    )
  }

// Cached reads. A missing file reads as None: whether that is an error
// depends on who asked.
let read = (env, path): option<content> =>
  need(env, `read:${path}`, async () =>
    (await env.fs.exists(path)) ? Some(split(await env.fs.readFile(path), path)) : None
  )
let exists = (env, path): bool => need(env, `exists:${path}`, () => env.fs.exists(path))
let files = (env, dir): array<string> => need(env, `files:${dir}`, () => env.fs.listFiles(dir))
let folders = (env, dir): array<string> => need(env, `dirs:${dir}`, () => env.fs.listDirs(dir))

let ordered = (names, order) => order == Some(Desc) ? Array.toReversed(names) : names

// Every file below `dir`, as paths relative to it.
let rec walk = (env, dir, prefix) => {
  let here = prefix == "" ? dir : join(dir, prefix)
  let (own, subs) = (attempt(() => files(env, here)), attempt(() => folders(env, here)))
  switch (own, subs) {
  | (Some(own), Some(subs)) =>
    Array.concat(own->Array.map(join(prefix, _)), all(subs, d => walk(env, dir, join(prefix, d)))->Array.flat)
  | _ => pending()
  }
}

/** The files a `dir` var or a `pages` entry selects, in path order (`order:
 desc` reverses it). A glob with a `/` or a `**` reaches into subfolders. An
 empty match fails loud unless `optional`. */
let listing = (env, dir, glob, order, optional, at) => {
  let deep = String.includes(glob, "/") || String.includes(glob, "**")
  let names =
    (deep ? walk(env, dir, "") : files(env, dir))
    ->Array.filter(matcher(glob))
    ->Array.toSorted(String.compare)
    ->ordered(order)
  if Array.length(names) == 0 && !optional {
    loud(`No files matching "${glob}" in ${dir} (declared at ${at})`)
  }
  all(names, n => {
    let path = join(dir, n)
    switch read(env, path) {
    | Some(c) => c
    | None => loud(`Content file not found: ${path} (declared at ${at})`)
    }
  })
}

// ---------------------------------------------------------------------------
// Contexts.

/** A top-level render site: fresh cycle stack, site-labeled errors. */
let top = (at, fn: unit => 'a): 'a => {
  stack := []
  cycle := None
  site(at, fn)
}

let kinds = ["file", "dir", "dirs", "list", "value"]

let rec make = (env, inline, tree: dict<node>): ctx =>
  carve(({derived}) => {
    env,
    inline,
    tree,
    vars: paths(tree)
    ->Dict.toArray
    ->Array.map(((p, n)) => (p, derived((self: ctx) => eval(n, p, self))))
    ->Dict.fromArray,
    get: derived((self: ctx) =>
      name =>
        switch Dict.get(self.vars, name) {
        | Some(d) => Some(d)
        | None => inner(self, name)
        }
    ),
  })
and sub = (self: ctx, layer) => make(self.env, self.inline, merge(self.tree, layer))
// A name reaching past a file group reads that file's frontmatter:
// `{{layouts.cv.title}}` is the `title` of the file `layouts.cv` loads.
and inner = (self, name) => {
  let segments = String.split(name, ".")
  let rec go = (d, i) =>
    switch Dict.get(d, Array.getUnsafe(segments, i)) {
    | Some(Group(g)) if i + 1 < Array.length(segments) => go(g, i + 1)
    | Some(_) => None
    | None if i > 0 && Dict.has(d, "file") =>
      let p = segments->Array.slice(~start=0, ~end=i)->Array.join(".")
      load(d, p, self)->Option.flatMap(c =>
        sub(self, c.front).get(segments->Array.slice(~start=i)->Array.join("."))
      )
    | None => None
    }
  go(self.tree, 0)
}
and eval = (n, p, self: ctx) =>
  switch n {
  | Leaf(s, _) => One(render(s, self.get))
  | List(items, _) => Many(items->Array.map(render(_, self.get)))
  | Fixed(d) => d
  | Body(c, transform) =>
    One(
      boxed(self.inline, () =>
        site(c.at, () => unpad(transform(render(c.body, sub(self, c.front).get)), c.pad))
      ),
    )
  | Group(d) =>
    switch kinds->Array.filter(k => Dict.has(d, k)) {
    | [] => fail(`{{${p}}} is a group (${Dict.keysToArray(d)->Array.join(", ")}), not a value`)
    | ["file"] => file(d, p, self)
    | ["dir"] => dir(d, p, self)
    | ["dirs"] => dirs(d, p, self)
    | ["list"] => list(d, p, self)
    | ["value"] => value(d, p, self)
    | several => fail(`{{${p}}} has several kinds (${several->Array.join(", ")}): keep one`)
    }
  }
// The site of a kind: the layer that declared its kind key, and its path.
and at = (d, key, p) =>
  switch Dict.get(d, key) {
  | Some(Leaf(_, o)) | Some(List(_, o)) => `${o.label}.${p}`
  | _ => p
  }
// A kind's fields. `text` renders in the context; `raw` is a template for a
// child context (`each`, `template`) or a literal (`join`, `list`); `path`
// anchors before it renders, so a ref never moves the anchor.
and text = (d, key, p, self) =>
  switch Dict.get(d, key) {
  | None => None
  | Some(Leaf(s, _)) => Some(render(s, self.get))
  | Some(_) => fail(`${at(d, key, p)}: "${key}" must be a string`)
  }
and raw = (d, key, p) =>
  switch Dict.get(d, key) {
  | None => None
  | Some(Leaf(s, _)) => Some(s)
  | Some(_) => fail(`${at(d, key, p)}: "${key}" must be a string`)
  }
and path = (d, key, p, self) =>
  switch Dict.get(d, key) {
  | Some(Leaf(s, o)) => site(`${at(d, key, p)} ${key}`, () => render(join(o.dir, s), self.get))
  | _ => fail(`${at(d, key, p)}: "${key}" must be a path`)
  }
and flag = (d, key, p, self) =>
  switch text(d, key, p, self) {
  | None | Some("false") => false
  | Some("true") => true
  | Some(v) => fail(`${at(d, key, p)}: "${key}" must be true or false, got "${v}"`)
  }
and order = (d, key, p, self) =>
  switch text(d, "order", p, self) {
  | None | Some("asc") => None
  | Some("desc") => Some(Desc)
  | Some(v) => fail(`${at(d, key, p)}: "order" must be "asc" or "desc", got "${v}"`)
  }
// The file a file group loads; None for a missing optional file.
and load = (d, p, self) => {
  let file = path(d, "file", p, self)
  switch read(self.env, file) {
  | Some(c) => Some(c)
  | None if flag(d, "optional", p, self) => None
  | None => loud(`Content file not found: ${file} (declared at ${at(d, "file", p)})`)
  }
}
and file = (d, p, self) => {
  let where = at(d, "file", p)
  switch load(d, p, self) {
  | None => One("")
  | Some(c) =>
    let transform = transformOf(self.env.transforms, c.path, text(d, "transform", p, self), where)
    One(
      boxed(self.inline, () =>
        site(c.at, () => {
          let front = sub(self, c.front)
          let body = unpad(transform(render(c.body, front.get)), c.pad)
          // Like a `list` wrapper: an empty body renders nothing, wrapper included.
          switch raw(d, "template", p) {
          | Some(template) if String.trim(body) != "" =>
            site(`${where} template`, () =>
              render(template, sub(front, Dict.fromArray([("body", fixed(body))])).get)
            )
          | Some(_) => ""
          | None => body
          }
        })
      ),
    )
  }
}
and dir = (d, p, self) => {
  let where = at(d, "dir", p)
  let folder = path(d, "dir", p, self)
  let glob = text(d, "glob", p, self)->Option.getOr("*.md")
  let explicit = text(d, "transform", p, self)
  let each = raw(d, "each", p)->Option.getOr("{{body}}")
  let items = listing(self.env, folder, glob, order(d, "dir", p, self), flag(d, "optional", p, self), where)
  let site_ = `dir ${folder} (${where})`
  One(
    site(site_, () =>
      items
      ->Array.map(c =>
        boxed(self.inline, () =>
          site(site_, () => {
            let transform = transformOf(self.env.transforms, c.path, explicit, where)
            // Each item's frontmatter stays local to it: eight chapters
            // would all define `title`.
            let front = sub(self, merge(naming(c), c.front))
            let body = unpad(transform(site(c.at, () => render(c.body, front.get))), c.pad)
            render(each, sub(front, Dict.fromArray([("body", fixed(body))])).get)
          })
        )
      )
      ->Array.join(raw(d, "join", p)->Option.getOr("\n"))
    ),
  )
}
and dirs = (d, p, self) => {
  let where = at(d, "dirs", p)
  let root = path(d, "dirs", p, self)
  let each = switch raw(d, "each", p) {
  | Some(each) => each
  | None => fail(`${where}: "dirs" needs an "each" template`)
  }
  let names = folders(self.env, root)->Array.toSorted(String.compare)->ordered(order(d, "dirs", p, self))
  if Array.length(names) == 0 && !flag(d, "optional", p, self) {
    loud(`No folders in ${root} (declared at ${where})`)
  }
  // The item vars load in each subfolder: their paths anchor there.
  let vars = switch Dict.get(d, "var") {
  | Some(Group(v)) => v
  | _ => Dict.make()
  }
  let label = switch Dict.get(d, "dirs") {
  | Some(Leaf(_, o)) => `${o.label}.${p}.var`
  | _ => `${p}.var`
  }
  One(
    site(`dirs ${root} (${where})`, () =>
      names
      ->Array.map(n => {
        let folder = join(root, n)
        let layer = merge(
          Dict.fromArray([("folder", group([("name", fixed(n))]))]),
          reanchor(vars, {dir: folder, label}),
        )
        boxed(self.inline, () => site(`folder ${folder} (${where})`, () => render(each, sub(self, layer).get)))
      })
      ->Array.join(raw(d, "join", p)->Option.getOr("\n"))
    ),
  )
}
and list = (d, p, self) => {
  let where = at(d, "list", p)
  let name = raw(d, "list", p)->Option.getOr("")
  let each = switch raw(d, "each", p) {
  | Some(each) => each
  | None => fail(`${where}: "list" needs an "each" template`)
  }
  One(
    boxed(self.inline, () =>
      site(where, () =>
        switch self.get(name) {
        | None => fail(`Undefined variable {{${name}}}`)
        | Some(One(_)) => fail(`"${name}" must resolve to a scalar list`)
        | Some(Many(items)) =>
          if Array.length(items) == 0 {
            ""
          } else {
            let one = (key, value, template) =>
              render(template, sub(self, Dict.fromArray([(key, fixed(value))])).get)
            let body =
              items
              ->Array.map(item => one("item", item, each))
              ->Array.join(raw(d, "join", p)->Option.getOr(""))
            switch raw(d, "template", p) {
            | Some(template) => one("body", body, template)
            | None => body
            }
          }
        }
      )
    ),
  )
}
and value = (d, p, self) => {
  let where = at(d, "value", p)
  let template = raw(d, "value", p)->Option.getOr("")
  let transform = switch raw(d, "transform", p) {
  | Some(name) => named(self.env.transforms, name, where)
  | None => fail(`${where}: "value" needs a "transform"`)
  }
  One(boxed(self.inline, () => site(where, () => transform(render(template, self.get)))))
}
and render = (template, get) => {
  // Every ref of a template is tried before a pending read stalls it, so the
  // reads of one template start together.
  let stalled = ref(false)
  let out = template->String.replaceRegExpBy2Unsafe(reference, (
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
      let out = attempt(() =>
        switch get(name) {
        | Some(One(s)) => s
        | Some(Many(a)) => a->Array.join("")
        | None => fail(`Undefined variable ${ref}${lined(input, offset)}`)
        }
      )
      stack := active
      switch out {
      | Some(s) => s
      | None =>
        stalled := true
        ""
      }
    }
  )
  if stalled.contents {
    pending()
  }
  out
}

// ---------------------------------------------------------------------------
// Configs and build entries.

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
  let env = {fs, transforms, cache: Dict.make(), started: Dict.make()}
  let shared =
    configs->Array.reduce(Dict.make(), (acc, c) =>
      merge(acc, nodes(c.vars, {dir: dirname(c.path), label: `var (${c.path})`}))
    )
  let last = Array.getUnsafe(configs, Array.length(configs) - 1)
  let here = dirname(last.path)
  // Every output path resolves before anything is written, so a collision
  // fails loud with nothing half-built.
  let plans = await Promise.all(
    last.build->Array.mapWithIndex(async (b, i) => {
      let at = `build[${Int.toString(i)}]`
      let own = nodes(b.vars, {dir: here, label: `${at}.var`})
      let entryCtx = () => make(env, inline, merge(shared, own))
      switch (b.input, b.pages) {
      | (Copy(_), Some(_)) => fail(`${at}: "pages" cannot be combined with a copy input`)
      | (Copy(path), None) =>
        let (source, output) = await settle(env, () => {
          let ctx = entryCtx()
          let source = top(`${at} input copy`, () => render(path, ctx.get))
          if !exists(env, source) {
            fail(`Copy source not found: ${source} (declared at ${at} input)`)
          }
          (source, top(`${at} output`, () => render(b.output, ctx.get)))
        })
        [{output, by: at, copy: true, write: () => fs.copy(source, output)}]
      | (input, pages) =>
        let origin = {dir: here, label: at}
        let node = switch input {
        | Node(d) =>
          let d = nodes(d, origin)
          if Dict.has(d, "file") && (Dict.has(d, "optional") || Dict.has(d, "template")) {
            fail(`${at} input: "optional" and "template" apply to file vars, not to a file input`)
          }
          Group(d)
        | Text(t) | Copy(t) => Leaf(t, origin)
        }
        // A file input contributes its frontmatter as the least local
        // templates — usable even in the output path.
        let context = layer => {
          let front = switch node {
          | Group(d) if Dict.has(d, "file") =>
            load(d, "input", entryCtx())->Option.mapOr(Dict.make(), c => c.front)
          | _ => Dict.make()
          }
          make(env, inline, merge(merge(merge(front, shared), layer), own))
        }
        let job = async (layer, page) => {
          let output = await settle(env, () =>
            top(`${at} output${page}`, () => render(b.output, context(layer).get))
          )
          let write = async () => {
            // Content errors can turn into boxes; output path errors never do —
            // a file cannot be written without a path.
            let out = await settle(env, () =>
              boxed(inline, () =>
                switch top(`${at} input${page}`, () => eval(node, "input", context(layer))) {
                | One(s) => s
                | Many(a) => a->Array.join("")
                }
              )
            )
            await fs.writeFile(output, out)
          }
          {output, by: `${at}${page}`, copy: false, write}
        }
        switch pages {
        | None => [await job(Dict.make(), "")]
        | Some(src) =>
          // One output per file. A page layers like a file input's
          // frontmatter — over the shared templates, under the entry's own
          // vars — and hands its rendered body over as `page`.
          let items = await settle(env, () => {
            let dir = top(`${at}.pages dir`, () => render(src.dir, entryCtx().get))
            let glob = src.glob->Option.getOr("*.md")
            listing(env, dir, glob, src.order, src.optional->Option.getOr(false), `${at}.pages`)
          })
          await Promise.all(
            items->Array.map(c => {
              let transform = transformOf(transforms, c.path, src.transform, `${at}.pages`)
              job(
                merge(merge(naming(c), c.front), Dict.fromArray([("page", Body(c, transform))])),
                ` (page ${c.path})`,
              )
            }),
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

type fsOptions = {allow?: array<string>}

// Node-backed FileSystem rooted at a path string or file:// URL (default: the
// current working directory). Creates parent directories on write.
//
// Every path stays inside the root, or inside a folder of `allow`: paths are
// templates that content can steer, so this door is where a page's
// frontmatter is kept from reading `~/.ssh` into the site or writing over
// anything outside the project. The check is lexical: symlinks are not
// followed.
let nodeFs = (root: option<string>, options: option<fsOptions>): filesystem => {
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
  let inside = (dir, path) => path == dir || String.startsWith(path, dir == "/" ? "/" : `${dir}/`)
  // The absolute, collapsed path — or a loud failure outside the fence.
  let resolve = async path => {
    let (_, base) = await mods()
    let base = canonical(base)
    let allowed = options->Option.flatMap(o => o.allow)->Option.getOr([])
    let full = canonical(absolute(base, path))
    if !inside(base, full) && !(allowed->Array.some(a => inside(canonical(absolute(base, a)), full))) {
      fail(
        `Path outside the project root: ${path} (resolves to ${full}; root ${base}) — ` ++
        `add its folder to nodeFs(root, { allow: [...] }) to read or write it`,
      )
    }
    full
  }
  let copying: dict<promise<unit>> = Dict.make()
  {
    readFile: async path => {
      let (fs, _) = await mods()
      await fs.readFile(await resolve(path), "utf8")
    },
    writeFile: async (path, content) => {
      let (fs, _) = await mods()
      let file = await resolve(path)
      await fs.mkdir(dirname(file), {recursive: true})
      await fs.writeFile(file, content, "utf8")
    },
    copy: async (source, output) => {
      let (fs, _) = await mods()
      let from = await resolve(source)
      let target = await resolve(output)
      // fs.cp races on a shared target (EEXIST on mkdir), so serialize per target.
      let previous = copying->Dict.get(target)->Option.getOr(Promise.resolve())
      let current = (
        async () => {
          try await previous catch {
          | _ => ()
          }
          await fs.mkdir(dirname(target), {recursive: true})
          await fs.cp(from, target, {recursive: true})
        }
      )()
      copying->Dict.set(target, current)
      await current
    },
    exists: async path => {
      let (fs, _) = await mods()
      let full = await resolve(path)
      try {
        await fs.access(full)
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
      let (fs, _) = await mods()
      let full = await resolve(dir)
      let entries = try {
        await fs.readdir(full, {withFileTypes: true, recursive: false})
      } catch {
      | _ => []
      }
      entries->Array.filter(isFile(_))->Array.map(dname(_))->Array.toSorted(String.compare)
    },
    listDirs: async dir => {
      let (fs, _) = await mods()
      let full = await resolve(dir)
      let entries = try {
        await fs.readdir(full, {withFileTypes: true, recursive: false})
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
  | None => nodeFs(None, None)
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

// The in-process build's filesystem: the one given, or Node's — which may
// also reach the extra folders the runner watches, since those are declared
// by the site's author, never by its content.
let watched = (options: watchOptions, root) =>
  switch options.fs {
  | Some(fs) => fs
  | None =>
    let allow = options.watch->Option.getOr([])->Array.map(w => String.startsWith(w, "/") ? w : join(root, w))
    nodeFs(None, Some({allow: allow}))
  }

let watch = async (options: watchOptions) => {
  let root = options.root->Option.getOr(Dev.cwd())
  let rebuild = switch options.build {
  | Some(path) => () => Dev.script(path, root)
  | None =>
    () =>
      run({
        glob: options.glob,
        fs: watched(options, root),
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
  | None => nodeFs(None, None)
  }
  let rebuild = switch options.build {
  | Some(path) => () => Dev.script(path, root)
  | None =>
    () =>
      run({
        glob: options.glob,
        fs: watched((options :> watchOptions), root),
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
