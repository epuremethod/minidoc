// Common `:::` blocks for minidoc sites. A block is read into nodes, the
// middle language, and the nodes are rendered to HTML. `blocks` joins the
// two into a minidoc transform.

open Node

type node = Node.t

type kinds = {kinds?: dict<string>}
type dialog = {owners?: dict<string>}
type api = {labels?: dict<string>}

/** A project's own block: its HTML from the rest of its opening line and its body. */
type extra = {name: string, fence?: bool, render: (string, string) => string}

type options = {
  callouts?: dict<string>,
  @as("ui-dialog") dialog?: dialog,
  sequence?: kinds,
  states?: kinds,
  api?: api,
  extra?: array<extra>,
  markdown?: Markdown.t => unit,
}

let common = [
  ("note", "Note"),
  ("draft", "Draft"),
  ("proposed", "Proposed"),
  ("settled", "Settled"),
  ("open", "Open question"),
  ("technical", "Technical"),
  ("principle", "Principle"),
  ("rejected", "Rejected"),
]

// The words an API call shows, which a site may translate.
let apiLabels = [
  ("query", "Query"),
  ("headers", "Headers"),
  ("body", "Body"),
  ("response", "Response"),
  ("empty", "Empty list"),
]

/** A quote's or callout's info: an author in double quotes, then a date, both optional. */
let byInfo = RegExp.fromString("^(?:\"([^\"]*)\")?(?:\\s*(\\S.*?))?\\s*$")

/** The end of an info that files its block in the annexe. */
let annexeTail = RegExp.fromString("^(.*?)(?:^|\\s)annexe$")

/** The end of an info that names its block: `#name`. */
let nameTail = RegExp.fromString(`^(.*?)(?:^|\\s)#(${Markdown.name})$`)

/** The end of an info that links its title to its source: `<url>`. */
let urlTail = RegExp.fromString("^(.*?)(?:^|\\s)<([^<>\\s]+)>$")

/** What the reader keeps of a whole page: each name with its line, the first block filed in the annexe, and the annexe's line. */
type page = {
  anchors: dict<int>,
  mutable filed: option<(string, int)>,
  mutable annexe: option<int>,
}

/** What a set of options resolves to, once per transform. */
type context = {
  md: Markdown.t,
  callouts: dict<string>,
  owners: dict<string>,
  sequenceKinds: dict<string>,
  statesKinds: dict<string>,
  apiLabels: dict<string>,
  extras: array<extra>,
  names: Scan.names,
  /** The long plans drawn so far in the page, which name their stage buttons. */
  mutable plans: int,
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
    apiLabels: Dict.fromArray([
      ...apiLabels,
      ...options.api->Option.flatMap(a => a.labels)->Option.mapOr([], Dict.toArray),
    ]),
    extras,
    names: {
      containers: [
        ...Dict.keysToArray(callouts),
        "quote",
        "annexe",
        "flow",
        "plan",
        "ui-dialog",
        "ui-form",
        "ui-flow",
        "api",
        ...extras->Array.filter(e => !isFence(e))->Array.map(e => e.name),
      ],
      fences: ["sequence", "states", "model", ...extras->Array.filter(isFence)->Array.map(e => e.name)],
    },
    plans: 0,
  }
}

let caption = info => info == "" ? None : Some(info)

let by = (name, info, line) =>
  switch RegExp.exec(byInfo, String.trim(info)) {
  | None => Html.fail(`Unknown block on line ${Int.toString(line)}: ${name} ${info}`)
  | Some(m) => (Sequence.capture(m, 0), Sequence.capture(m, 1))
  }

/** A quote's or callout's info: its author, its date, its source, its name, and whether it goes to the annexe. */
let named = (page, name, info, line) => {
  let at = Int.toString(line)
  let info = String.trim(info)
  let (info, annexe) = switch RegExp.exec(annexeTail, info) {
  | Some(m) => (String.trim(Scan.capture(m, 0)), true)
  | None => (info, false)
  }
  let (info, anchor) = switch RegExp.exec(nameTail, info) {
  | Some(m) => (String.trim(Scan.capture(m, 0)), Sequence.capture(m, 1))
  | None => (info, None)
  }
  let (info, url) = switch RegExp.exec(urlTail, info) {
  | Some(m) => (String.trim(Scan.capture(m, 0)), Sequence.capture(m, 1))
  | None => (info, None)
  }
  let (author, date) = by(name, info, line)
  switch (url, author) {
  | (Some(url), None) => Html.fail(`Source without a title on line ${at}: <${url}>`)
  | _ => ()
  }
  switch anchor {
  | None => annexe ? Html.fail(`Annexe without a name on line ${at}`) : ()
  | Some(anchor) =>
    if author == None {
      Html.fail(`Named block without a title on line ${at}: #${anchor}`)
    }
    switch page.anchors->Dict.get(anchor) {
    | Some(first) => Html.fail(`Duplicate name on line ${at}: #${anchor}, first on line ${Int.toString(first)}`)
    | None => page.anchors->Dict.set(anchor, line)
    }
    if annexe && page.filed == None {
      page.filed = Some((anchor, line))
    }
  }
  (author, date, url, anchor, annexe)
}

/** Call `f` on each node, and on each node inside it. */
let rec each = (nodes, f) =>
  nodes->Array.forEach(node => {
    f(node)
    switch node {
    | Callout({children}) | Quote({children}) | Screens({children}) => each(children, f)
    | _ => ()
    }
  })

/** The author and date under a quote or callout, or nothing when it names neither. A source makes the author a link. */
let byline = (author, date, url, ~tag, ~className) => {
  let title = a => url->Option.mapOr(Html.escape(a), u => `<a href="${Html.escape(u)}">${Html.escape(a)}</a>`)
  let parts = [
    author->Option.map(a => `<cite>${title(a)}</cite>`),
    date->Option.map(d => `<span class="${className}__date">${Html.escape(d)}</span>`),
  ]->Array.keepSome
  parts == [] ? "" : `<${tag}${tag == "p" ? ` class="${className}__by"` : ""}>— ${parts->Array.join(", ")}</${tag}>`
}

let rec readIn = (ctx, page, source, offset) =>
  Scan.scan(source, offset, ctx.names)->Array.map(item =>
    switch item {
    | Run(text) => Markdown(text)
    | Block({name, info, body, line}) =>
      let inner = () => readIn(ctx, page, body, line + 1)
      switch name {
      | "quote" =>
        let (author, date, url, anchor, annexe) = named(page, name, info, line)
        Quote({author, date, url, anchor, annexe, children: inner()})
      | "annexe" =>
        let at = Int.toString(line)
        if page.annexe != None {
          Html.fail(`Second annexe on line ${at}`)
        }
        if String.trim(body) != "" {
          Html.fail(`Annexe with a body on line ${at}`)
        }
        page.annexe = Some(line)
        Annexe
      | "flow" => Flow.read(ctx.md, body, "Flow")
      | "plan" => Plan.read(ctx.md, info, body, line)
      | "ui-dialog" =>
        let (owner, title, widgets) = Screen.read(info, body, ctx.owners)
        Dialog({owner, title, widgets})
      | "ui-form" =>
        let (owner, title, widgets) = Screen.read(info, body, ctx.owners)
        Form({owner, title, widgets})
      | "ui-flow" => Screens({caption: caption(info), children: inner()})
      | "api" => Api.read(info, body, line)
      | "sequence" => Sequence(Sequence.read(body, caption(info), ctx.sequenceKinds))
      | "states" => States(States.read(body, caption(info), ctx.statesKinds))
      | "model" => Model(Model.read(body, caption(info)))
      | _ =>
        switch ctx.callouts->Dict.get(name) {
        | Some(label) =>
          let (author, date, url, anchor, annexe) = named(page, name, info, line)
          Callout({name, label, author, date, url, anchor, annexe, children: inner()})
        | None => Extra({name, info, body})
        }
      }
    }
  )

/** The link a block filed in the annexe leaves in its place. */
let filedLink = (anchor, author) =>
  `<p class="annexe__ref"><a href="#${anchor}">${Html.escape(author->Option.getOr(""))}</a></p>\n`

let id = anchor => anchor->Option.mapOr("", a => ` id="${a}"`)

// `filed` is the page's blocks filed in the annexe, in order. A filed block
// is drawn whole only in the annexe, where `whole` is set.
let rec renderIn = (ctx, nodes, env, filed, ~whole=false) =>
  nodes
  ->Array.map(node =>
    switch node {
    | Markdown(text) => Markdown.render(ctx.md, text, env)
    | Callout({anchor: Some(anchor), author, annexe: true}) | Quote({anchor: Some(anchor), author, annexe: true})
      if !whole =>
      filedLink(anchor, author)
    | Callout({name, label, author, date, url, anchor, children}) =>
      let label = Html.escape(label)
      let under = byline(author, date, url, ~tag="p", ~className="callout")
      `<aside class="callout callout--${name}"${id(anchor)} aria-label="${label}"><p class="callout__label">${label}</p><div class="callout__body">\n${renderIn(
          ctx,
          children,
          env,
          filed,
        )}</div>${under}</aside>\n`
    | Quote({author, date, url, anchor, children}) =>
      let under = byline(author, date, url, ~tag="figcaption", ~className="quote")
      `<figure class="quote"${id(anchor)}><blockquote>\n${renderIn(ctx, children, env, filed)}</blockquote>${under}</figure>\n`
    | Annexe =>
      filed == []
        ? ""
        : `<section class="annexe">\n${filed
            ->Array.map(node => renderIn(ctx, [node], env, filed, ~whole=true))
            ->Array.join("")}</section>\n`
    | Flow({label, columns}) => Flow.render(ctx.md, label, columns)
    | Plan({title, stages, todos}) =>
      let long = Plan.long(stages)
      if long {
        ctx.plans = ctx.plans + 1
      }
      Plan.render(ctx.md, title, stages, todos, ~name=`plan-${Int.toString(ctx.plans)}`)
    | Dialog({owner, title, widgets}) => Screen.render(ctx.md, owner, title, widgets)
    | Form({owner, title, widgets}) => Screen.render(~form=true, ctx.md, owner, title, widgets)
    | Screens({caption, children}) => Screen.renderFlow(caption, renderIn(ctx, children, env, filed))
    | Api({method, path, title, parts}) => Api.render(method, path, title, parts, ctx.apiLabels)
    | Sequence(drawing) => Sequence.render(drawing) ++ "\n"
    | States(drawing) => States.render(drawing) ++ "\n"
    | Model(drawing) => Model.render(drawing) ++ "\n"
    | Extra({name, info, body}) =>
      switch ctx.extras->Array.find(e => e.name == name) {
      | Some(e) => e.render(info, body)
      | None => ""
      }
    }
  )
  ->Array.join("")

// The first line of the page that holds a reference to `name`.
let referenceLine = (source, name) => {
  let at = switch String.indexOf(source, `\`(${name})\``) {
  | -1 => String.indexOf(source, `(${name})`)
  | at => at
  }
  source->String.slice(~start=0, ~end=at)->String.split("\n")->Array.length
}

/** Read a whole page: its blocks, then the checks that need all of them. */
let readPage = (ctx, source) => {
  let page = {anchors: Dict.make(), filed: None, annexe: None}
  let nodes = readIn(ctx, page, source, 1)
  switch (page.filed, page.annexe) {
  | (Some((anchor, line)), None) =>
    Html.fail(`No ::: annexe for the block on line ${Int.toString(line)}: #${anchor}`)
  | _ => ()
  }
  nodes->each(node =>
    switch node {
    | Markdown(text) =>
      Markdown.references(ctx.md, text)->Array.forEach(name =>
        if !(page.anchors->Dict.has(name)) {
          Html.fail(`Unknown reference on line ${Int.toString(referenceLine(source, name))}: (${name})`)
        }
      )
    | _ => ()
    }
  )
  nodes
}

/** Render a whole page: references get their block's title, and filed blocks go to the annexe. */
let renderPage = (ctx, nodes, env) => {
  ctx.plans = 0
  let titles = Dict.make()
  let filed = []
  nodes->each(node =>
    switch node {
    | Callout({anchor: Some(anchor), author: Some(title), annexe})
    | Quote({anchor: Some(anchor), author: Some(title), annexe}) =>
      titles->Dict.set(anchor, title)
      if annexe {
        filed->Array.push(node)
      }
    | _ => ()
    }
  )
  Markdown.setTitles(env, titles)
  renderIn(ctx, nodes, env, filed)
}

let read = (source, options) => readPage(context(options), source)

let write = Write.write

let render = (nodes, options) => {
  let ctx = context(options)
  renderPage(ctx, nodes, Markdown.env())
}

let blocks = options => {
  let ctx = context(options)
  source => {
    // One environment for the whole page, so a link reference defined in
    // one run resolves in every other.
    let env = Markdown.env()
    Markdown.parse(ctx.md, source, env)->ignore
    renderPage(ctx, readPage(ctx, source), env)
  }
}
