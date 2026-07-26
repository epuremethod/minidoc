// MinidocTilia — experiment: every scope layer is a tilia carve. A child layer
// re-hosts its parent's *templates* (dict merge, own wins) rather than chaining
// value lookups — so inherited templates re-resolve against local overrides
// (dynamic-scoping behavior) while every layer's computeds cache soundly.
// Error handling is intentionally crude; failing fixtures are findings.

open Schema
open Tilia

/** A loaded content file: frontmatter split off, transform resolved. */
type content = {body: string, transform: string => string, front: dict<data>}

/** A loaded var, ready to evaluate in a context. */
type lvar =
  | T(string) // template scalar
  | L(array<string>) // list of template scalars
  | V(data) // pre-rendered value — no further expansion
  | F(content) // file
  | D(array<content>, string) // dir items + each template
  | R(listv) // list renderer
  | P(string, string => string) // template + transform

/** One scope layer: a carve of every template visible to it. */
type ctx = {lvars: dict<lvar>, vars: dict<data>, get: string => option<data>}

let reference = RegExp.fromString("\\{\\{\\s*([A-Za-z_][A-Za-z0-9_.-]*)\\s*\\}\\}", ~flags="g")

// Termination guard only — a cycle should fail, not hang the suite.
let depth = ref(0)

/** Child templates shadow the parent's. */
let over = (parent, own) => Dict.assign(Dict.copy(parent), own)

let data = front =>
  front->Dict.mapValues(d =>
    switch d {
    | One(s) => T(s)
    | Many(a) => L(a)
    }
  )

let rec make = (lvars: dict<lvar>): ctx =>
  carve(({derived}) => {
    lvars,
    vars: lvars->Dict.mapValues(lv => derived((self: ctx) => eval(lv, self))),
    get: derived((self: ctx) => name => Dict.get(self.vars, name)),
  })
and sub = (self: ctx, extra: dict<lvar>) => make(over(self.lvars, extra))
and eval = (lv, self: ctx) =>
  switch lv {
  | T(s) => One(render(s, self.get))
  | L(items) => Many(items->Array.map(render(_, self.get)))
  | V(d) => d
  | P(value, transform) => One(transform(render(value, self.get)))
  | F(c) => One(c.transform(render(c.body, sub(self, data(c.front)).get)))
  | D(items, each) =>
    One(
      items
      ->Array.map(c => {
        let front = sub(self, data(c.front))
        let body = c.transform(render(c.body, front.get))
        render(each, sub(front, Dict.fromArray([("body", V(One(body)))])).get)
      })
      ->Array.join("\n"),
    )
  | R(l) =>
    switch self.get(l.list) {
    | Some(Many(items)) if Array.length(items) > 0 =>
      let one = (name, value, template) =>
        render(template, sub(self, Dict.fromArray([(name, V(One(value)))])).get)
      let body = items->Array.map(item => one("item", item, l.each))->Array.join(l.join->Option.getOr(""))
      One(
        switch l.template {
        | Some(template) => one("body", body, template)
        | None => body
        },
      )
    | _ => One("")
    }
  }
and render = (template, get) =>
  // Throwing here would be caught and retried by the computed — a sync loop —
  // so a cycle degrades to a marker string instead. Finding, not a fix.
  if depth.contents > 8 {
    "[cycle]"
  } else {
    depth := depth.contents + 1
    let out = template->String.replaceRegExpBy1Unsafe(reference, (
      ~match as ref,
      ~group1 as name,
      ~offset as _,
      ~input as _,
    ) =>
      switch get(name) {
      | Some(One(s)) => s
      | Some(Many(a)) => a->Array.join("")
      | None => fail(`Undefined variable ${ref}`)
      }
    )
    depth := depth.contents - 1
    out
  }

// ---------------------------------------------------------------------------
// Loading — read configs and content up front; contexts are built after.

module Md = {
  type opts = {@as("async") sync: bool}
  @module("marked") @scope("marked") external parse: (string, opts) => string = "parse"
}

let defaults: dict<string => string> = Dict.fromArray([
  ("md", text => Md.parse(text, {sync: false})),
  ("none", text => text),
])

let special = RegExp.fromString("[.*+?^${}()|[\\]\\\\]", ~flags="g")

// `*` glob over basenames — enough for dir vars in the experiment.
let matcher = glob => {
  let source =
    glob
    ->String.split("*")
    ->Array.map(part => String.replaceRegExp(part, special, "\\$&"))
    ->Array.join("[^/]*")
  let re = RegExp.fromString(`^${source}$`)
  name => re->RegExp.test(name)
}

let matter = RegExp.fromString("^---\\n(?:([\\s\\S]*?)\\n)?---(?:\\n|$)")

type page = {front: dict<data>, body: string}

let split = (text, at) =>
  if !String.startsWith(text, "---\n") {
    {front: Dict.make(), body: text}
  } else {
    switch RegExp.exec(matter, text) {
    | None => fail(`${at}: unterminated frontmatter`)
    | Some(m) =>
      let vars = switch m->RegExp.Result.matches->Array.get(0) {
      | Some(Some(head)) => front(head, at)
      | _ => Dict.make()
      }
      {front: vars, body: String.slice(text, ~start=String.length(RegExp.Result.fullMatch(m)))}
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

// Scalar-only lookup for `{{refs}}` inside declared paths.
let strs = (vars: dict<varv>, parent) => {
  let rec get = name =>
    switch Dict.get(vars, name) {
    | Some(Scalar(s)) => Some(One(render(s, get)))
    | _ => parent(name)
    }
  get
}

/** Load one `var` block: its lvars plus the frontmatter its file vars export. */
let load = async (fs: Minidoc.filesystem, transforms, pget, vars: dict<varv>) => {
  let out: dict<lvar> = Dict.make()
  let exports: dict<lvar> = Dict.make()
  let content = async (path, explicit) => {
    let {front, body} = split(await fs.readFile(path), path)
    let name = explicit->Option.orElse(infer(path))->Option.getOr("none")
    switch Dict.get(transforms, name) {
    | Some(transform) => {body, transform, front}
    | None => fail(`unknown transform "${name}"`)
    }
  }
  await seq(Dict.toArray(vars), 0, async ((name, v)) =>
    switch v {
    | Scalar(s) => Dict.set(out, name, T(s))
    | Scalars(a) => Dict.set(out, name, L(a))
    | ListV(l) => Dict.set(out, name, R(l))
    | PipeV(p) =>
      switch Dict.get(transforms, p.transform) {
      | Some(t) => Dict.set(out, name, P(p.value, t))
      | None => fail(`unknown transform "${p.transform}"`)
      }
    | FileV(f) =>
      let c = await content(render(f.file, pget), f.transform)
      Dict.toArray(data(c.front))->Array.forEach(((k, lv)) => Dict.set(exports, k, lv))
      Dict.set(out, name, F(c))
    | DirV(d) =>
      let dir = render(d.dir, pget)
      let names = (await fs.listFiles(dir))->Array.filter(matcher(d.glob->Option.getOr("*.md")))
      let items = await Promise.all(names->Array.map(n => content(join(dir, n), d.transform)))
      Dict.set(out, name, D(items, d.each->Option.getOr("{{body}}")))
    }
  )
  (out, exports)
}

// Config chain, base-most first: a base contributes templates the child
// re-hosts (and may shadow) in its own context.
let rec chain = async (fs: Minidoc.filesystem, path, visited) => {
  if Array.includes(visited, path) {
    fail(`Base config cycle: ${path}`)
  }
  let config = parse(await fs.readFile(path), path)
  switch config.base {
  | Some(base) => Array.concat(await chain(fs, base, [...visited, path]), [config])
  | None => [config]
  }
}

let exec = async (fs: Minidoc.filesystem, transforms, entry) => {
  let configs = await chain(fs, entry, [])
  let pget = configs->Array.reduce(_ => None, (parent, c) => strs(c.vars, parent))
  let rec grow = async (acc, i) =>
    if i >= Array.length(configs) {
      acc
    } else {
      let (own, exports) = await load(fs, transforms, pget, Array.getUnsafe(configs, i).vars)
      await grow(over(over(acc, exports), own), i + 1)
    }
  let shared = await grow(Dict.make(), 0)
  let entry = Array.getUnsafe(configs, Array.length(configs) - 1)
  await Promise.all(
    entry.build->Array.map(async b => {
      let bpget = strs(b.vars, pget)
      let (own, exports) = await load(fs, transforms, bpget, b.vars)
      let layer = front => make(over(over(over(front, shared), exports), own))
      switch b.input {
      | Copy(path) => await fs.copy(render(path, bpget), render(b.output, layer(Dict.make()).get))
      | input =>
        // A file input contributes its frontmatter as the least local templates.
        let (lv, bctx) = switch input {
        | Text(t) => (T(t), layer(Dict.make()))
        | FileI(f) =>
          let {front, body} = split(await fs.readFile(render(f.file, bpget)), f.file)
          let name = f.transform->Option.orElse(infer(f.file))->Option.getOr("none")
          let transform = Dict.get(transforms, name)->Option.getOr(text => text)
          (F({body, transform, front}), layer(data(front)))
        | DirI(d) =>
          let dir = render(d.dir, bpget)
          let names = (await fs.listFiles(dir))->Array.filter(matcher(d.glob->Option.getOr("*.md")))
          let items = await Promise.all(
            names->Array.map(async n => {
              let {front, body} = split(await fs.readFile(join(dir, n)), n)
              let name = d.transform->Option.orElse(infer(n))->Option.getOr("none")
              {body, transform: Dict.get(transforms, name)->Option.getOr(text => text), front}
            }),
          )
          (D(items, d.each->Option.getOr("{{body}}")), layer(Dict.make()))
        | Copy(_) => (T(""), layer(Dict.make()))
        }
        let out = switch eval(lv, bctx) {
        | One(s) => s
        | Many(a) => a->Array.join("")
        }
        await fs.writeFile(render(b.output, bctx.get), out)
      }
    }),
  )
}

/** Same public shape as Minidoc.run; `fs` is required in the experiment. */
let run = async (options: Minidoc.runOptions) => {
  let fs = switch options.fs {
  | Some(fs) => fs
  | None => fail("MinidocTilia: fs is required")
  }
  let transforms = Dict.assign(Dict.copy(defaults), options.transform->Option.getOr(Dict.make()))
  let configs = await fs.glob(options.glob)
  if Array.length(configs) == 0 {
    fail(`No config files match "${options.glob}"`)
  }
  let _ = await Promise.all(configs->Array.map(config => exec(fs, transforms, config)))
}
