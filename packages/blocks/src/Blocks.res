// Common `:::` blocks for minidoc sites. A block is read into nodes, the
// middle language, and the nodes are rendered to HTML. `blocks` joins the
// two into a minidoc transform.

open Node

type node = Node.t

type kinds = {kinds?: dict<string>}
type dialog = {owners?: dict<string>}

/** A project's own block: its HTML from the rest of its opening line and its body. */
type extra = {name: string, fence?: bool, render: (string, string) => string}

type options = {
  callouts?: dict<string>,
  @as("ui-dialog") dialog?: dialog,
  sequence?: kinds,
  states?: kinds,
  extra?: array<extra>,
  markdown?: Markdown.t => unit,
}

let common = [
  ("note", "Note"),
  ("draft", "Draft"),
  ("settled", "Settled"),
  ("open", "Open question"),
  ("technical", "Technical"),
  ("principle", "Principle"),
  ("rejected", "Rejected"),
]

let quoteInfo = RegExp.fromString("^quote(?:\\s+\"([^\"]*)\")?(?:\\s+(\\S.*?))?\\s*$")

/** What a set of options resolves to, once per transform. */
type context = {
  md: Markdown.t,
  callouts: dict<string>,
  owners: dict<string>,
  sequenceKinds: dict<string>,
  statesKinds: dict<string>,
  extras: array<extra>,
  names: Scan.names,
}

let context = (options: options) => {
  let callouts = Dict.fromArray([...common, ...options.callouts->Option.mapOr([], Dict.toArray)])
  let extras = options.extra->Option.getOr([])
  let isFence = (e: extra) => e.fence->Option.getOr(false)
  {
    md: Markdown.make(options.markdown),
    callouts,
    owners: options.dialog->Option.flatMap(d => d.owners)->Option.getOr(Dict.make()),
    sequenceKinds: options.sequence->Option.flatMap(k => k.kinds)->Option.getOr(Dict.make()),
    statesKinds: options.states->Option.flatMap(k => k.kinds)->Option.getOr(Dict.make()),
    extras,
    names: {
      containers: [
        ...Dict.keysToArray(callouts),
        "quote",
        "flow",
        "ui-dialog",
        "ui-flow",
        ...extras->Array.filter(e => !isFence(e))->Array.map(e => e.name),
      ],
      fences: ["sequence", "states", ...extras->Array.filter(isFence)->Array.map(e => e.name)],
    },
  }
}

let caption = info => info == "" ? None : Some(info)

let rec readIn = (ctx, source, offset) =>
  Scan.scan(source, offset, ctx.names)->Array.map(item =>
    switch item {
    | Run(text) => Markdown(text)
    | Block({name, info, body, line}) =>
      let inner = () => readIn(ctx, body, line + 1)
      switch name {
      | "quote" =>
        switch RegExp.exec(quoteInfo, String.trim(`quote ${info}`)) {
        | None => Html.fail(`Unknown block on line ${Int.toString(line)}: quote ${info}`)
        | Some(m) =>
          Quote({author: Sequence.capture(m, 0), date: Sequence.capture(m, 1), children: inner()})
        }
      | "flow" => Flow.read(ctx.md, body, "Flow")
      | "ui-dialog" => Screen.read(info, body, ctx.owners)
      | "ui-flow" => Screens({caption: caption(info), children: inner()})
      | "sequence" => Sequence(Sequence.read(body, caption(info), ctx.sequenceKinds))
      | "states" => States(States.read(body, caption(info), ctx.statesKinds))
      | _ =>
        switch ctx.callouts->Dict.get(name) {
        | Some(label) => Callout({name, label, children: inner()})
        | None => Extra({name, info, body})
        }
      }
    }
  )

let rec renderIn = (ctx, nodes, env) =>
  nodes
  ->Array.map(node =>
    switch node {
    | Markdown(text) => Markdown.render(ctx.md, text, env)
    | Callout({name, label, children}) =>
      let label = Html.escape(label)
      `<aside class="callout callout--${name}" aria-label="${label}"><p class="callout__label">${label}</p><div class="callout__body">\n${renderIn(
          ctx,
          children,
          env,
        )}</div></aside>\n`
    | Quote({author, date, children}) =>
      let parts = [
        author->Option.map(a => `<cite>${Html.escape(a)}</cite>`),
        date->Option.map(d => `<span class="quote__date">${Html.escape(d)}</span>`),
      ]->Array.keepSome
      let under = parts == [] ? "" : `<figcaption>— ${parts->Array.join(", ")}</figcaption>`
      `<figure class="quote"><blockquote>\n${renderIn(ctx, children, env)}</blockquote>${under}</figure>\n`
    | Flow({label, columns}) => Flow.render(ctx.md, label, columns)
    | Dialog({owner, title, widgets}) => Screen.render(ctx.md, owner, title, widgets)
    | Screens({caption, children}) => Screen.renderFlow(caption, renderIn(ctx, children, env))
    | Sequence(drawing) => Sequence.render(drawing) ++ "\n"
    | States(drawing) => States.render(drawing) ++ "\n"
    | Extra({name, info, body}) =>
      switch ctx.extras->Array.find(e => e.name == name) {
      | Some(e) => e.render(info, body)
      | None => ""
      }
    }
  )
  ->Array.join("")

let read = (source, options) => readIn(context(options), source, 1)

let write = Write.write

let render = (nodes, options) => {
  let ctx = context(options)
  renderIn(ctx, nodes, Markdown.env())
}

let blocks = options => {
  let ctx = context(options)
  source => {
    // One environment for the whole page, so a link reference defined in
    // one run resolves in every other.
    let env = Markdown.env()
    Markdown.parse(ctx.md, source, env)->ignore
    renderIn(ctx, readIn(ctx, source, 1), env)
  }
}
