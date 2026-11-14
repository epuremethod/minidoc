// The text form of the nodes: the kind first, then the fields, quoted
// strings, bare flags, two spaces of indent for each level, and `| ` before
// each line of markdown. Numbers are rounded to two decimals here only.

open Node

let quote = text => `"${String.replaceAll(text, "\"", "\\\"")}"`
let num = v => Float.toString(Math.round(v *. 100.) /. 100.)
let nums = values => values->Array.map(num)->Array.join(" ")

let field = (name, value) => value->Option.mapOr("", v => ` ${name} ${quote(v)}`)
let flag = (name, on) => on ? ` ${name}` : ""

let markdown = (text, pad) =>
  text->String.split("\n")->Array.map(line => line == "" ? `${pad}|` : `${pad}| ${line}`)

let keys = (drawing: drawing<_>, pad) =>
  [
    ...drawing.caption->Option.mapOr([], c => [`${pad}caption ${quote(c)}`]),
    ...drawing.keys->Array.map(k => `${pad}key ${k.kind} ${quote(k.text)}${flag("move", k.move)}`),
  ]

let sequenceOp = (op: SequenceOp.t, pad) =>
  switch op {
  | Frame({left, top, width, height}) => [`${pad}frame ${nums([left, top, width, height])}`]
  | Head({kind, x, y, width, height, name, color}) => [
      `${pad}head ${kind} ${nums([x, y, width, height])} ${quote(name)}${field("color", color)}`,
    ]
  | Life({x, top, bottom}) => [`${pad}life ${nums([x, top, bottom])}`]
  | Message({from, to, y, refused, label, color}) => [
      `${pad}${refused ? "refused" : "message"} ${nums([from, to, y])}${field("color", color)}`,
      ...label->Option.mapOr([], l => [`${pad}  label ${nums([l.x, l.y])} ${quote(l.text)}`]),
    ]
  | State({x, y, width, height, text, color}) => [
      `${pad}state ${nums([x, y, width, height])} ${quote(text)}${field("color", color)}`,
    ]
  }

let statesOp = (op: StatesOp.t, pad) =>
  switch op {
  | Frame({left, top, width, height}) => [`${pad}frame ${nums([left, top, width, height])}`]
  | Box({kind, x, y, width, height, name, active, color}) => [
      `${pad}box ${kind} ${nums([x, y, width, height])} ${quote(name)}${active ? " active" : ""}${field("color", color)}`,
    ]
  | Move({kind, color, both, points, label}) => [
      `${pad}move${kind->Option.mapOr("", k => ` ${k}`)}${flag("both", both)} ${nums(points)}${field("color", color)}`,
      ...label->Option.mapOr([], ((l, anchor)) => [
        `${pad}  label ${nums([l.x, l.y])} ${anchor} ${quote(l.text)}`,
      ]),
    ]
  }

let placed = (label, pad) =>
  label->Option.mapOr([], ((l: label, anchor)) => [`${pad}  label ${nums([l.x, l.y])} ${anchor} ${quote(l.text)}`])

let modelOp = (op: ModelOp.t, pad) =>
  switch op {
  | Frame({left, top, width, height}) => [`${pad}frame ${nums([left, top, width, height])}`]
  | Table({x, y, width, height, name, tenant, color, kindX, valueX, columns, groups}) => [
      `${pad}table ${nums([x, y, width, height, kindX, valueX])} ${quote(name)}${field("tenant", tenant)}${field("color", color)}`,
      // Columns and groups, top to bottom.
      ...[
        ...columns->Array.map(c => (
          c.y,
          `${pad}  column ${num(c.y)} ${quote(c.name)}${field("color", c.nameColor)}${field("type", c.kind)}${field(
              "color",
              c.kindColor,
            )}${field("value", c.value)}${field("color", c.valueColor)}`,
        )),
        ...groups->Array.map(g => (
          g.y,
          `${pad}  group ${num(g.y)}${g.name->Option.mapOr("", n => ` ${quote(n)}`)}${field("color", g.color)}${g.from->Option.mapOr("", f => ` from ${num(f)}`)}`,
        )),
      ]
      ->Array.toSorted(((a, _), (b, _)) => a -. b)
      ->Array.map(Pair.second),
    ]
  | Link({from, to, points, label, color}) => [
      `${pad}link ${Model.arityName(from)} ${Model.arityName(to)} ${nums(points)}${field("color", color)}`,
      ...placed(label, pad),
    ]
  | Parent({points, label, color}) => [`${pad}parent ${nums(points)}${field("color", color)}`, ...placed(label, pad)]
  | Process({points, label, color}) => [
      `${pad}process ${nums(points)}${field("color", color)}`,
      ...placed(label, pad),
    ]
  }

let widget = (w, pad) =>
  switch w {
  | Text(text) => markdown(text, pad)
  | Actions(buttons) => [
      `${pad}actions`,
      ...buttons->Array.map(b => `${pad}  button ${quote(b.text)}${flag("primary", b.primary)}${flag("clicked", b.clicked)}`),
    ]
  | Options(choices) => [
      `${pad}options`,
      ...choices->Array.map(c => `${pad}  ${c.radio ? "radio" : "check"} ${quote(c.text)}${flag("on", c.on)}`),
    ]
  | Field({label, value, select, buttons}) => [
      `${pad}field ${quote(label)}${field("value", value)}${flag("select", select)}`,
      ...buttons->Array.map(b => `${pad}  button ${quote(b.text)}${flag("primary", b.primary)}${flag("clicked", b.clicked)}`),
    ]
  }

let rec lines = (node, pad) => {
  let inner = `${pad}  `
  let children = nodes => nodes->Array.flatMap(n => lines(n, inner))
  switch node {
  | Markdown(text) => markdown(text, pad)
  | Callout({name, label, author, date, url, anchor, annexe, children: c}) => [
      `${pad}callout ${name} ${quote(label)}${field("author", author)}${field("date", date)}${field(
          "url",
          url,
        )}${field("anchor", anchor)}${flag("annexe", annexe)}`,
      ...children(c),
    ]
  | Quote({author, date, url, anchor, annexe, children: c}) => [
      `${pad}quote${field("author", author)}${field("date", date)}${field("url", url)}${field("anchor", anchor)}${flag(
          "annexe",
          annexe,
        )}`,
      ...children(c),
    ]
  | Annexe => [`${pad}annexe`]
  | Flow({label, columns}) => [
      `${pad}flow ${quote(label)}`,
      ...columns->Array.flatMap(column => [
        `${inner}column${column.title->Option.mapOr("", t => ` ${quote(t)}`)}`,
        ...column.steps->Array.flatMap(step => [
          `${inner}  step ${quote(step.text)}`,
          ...step.details->Array.map(d => `${inner}    detail ${quote(d)}`),
        ]),
      ]),
    ]
  | Plan({title, stages, todos}) =>
    let todo = (t: todo, pad) => `${pad}todo${flag("done", t.done)} ${quote(t.text)}`
    let state = s =>
      switch s {
      | Done => " done"
      | Doing => " doing"
      | NotStarted => ""
      }
    [
      `${pad}plan${field("title", title)}`,
      ...stages->Array.flatMap(s => [
        `${inner}stage${state(s.state)} ${quote(s.title)}${field("message", s.message)}`,
        ...s.todos->Array.map(t => todo(t, `${inner}  `)),
      ]),
      ...todos->Array.map(t => todo(t, inner)),
    ]
  | Dialog({owner, title, widgets}) => [
      `${pad}ui-dialog${owner->Option.mapOr("", ((key, label)) => ` owner ${key} ${quote(label)}`)}${field(
          "title",
          title,
        )}`,
      ...widgets->Array.flatMap(w => widget(w, inner)),
    ]
  | Form({owner, title, widgets}) => [
      `${pad}ui-form${owner->Option.mapOr("", ((key, label)) => ` owner ${key} ${quote(label)}`)}${field(
          "title",
          title,
        )}`,
      ...widgets->Array.flatMap(w => widget(w, inner)),
    ]
  | Screens({caption, children: c}) => [`${pad}ui-flow${field("caption", caption)}`, ...children(c)]
  | Api({method, path, title, parts}) => [
      `${pad}api ${method} ${quote(path)}${field("title", title)}`,
      ...parts->Array.flatMap(p => [
        `${inner}${p.name}${p.status->Option.mapOr("", s => ` ${s}`)}${field("caption", p.caption)}`,
        ...(p.value == JSON.Null ? [] : [`${inner}  ${JSON.stringify(p.value)}`]),
      ]),
    ]
  | Sequence(drawing) => [
      `${pad}sequence`,
      ...drawing.ops->Array.flatMap(op => sequenceOp(op, inner)),
      ...keys(drawing, inner),
    ]
  | States(drawing) => [
      `${pad}states`,
      ...drawing.ops->Array.flatMap(op => statesOp(op, inner)),
      ...keys(drawing, inner),
    ]
  | Model(drawing) => [
      `${pad}model`,
      ...drawing.ops->Array.flatMap(op => modelOp(op, inner)),
      ...keys(drawing, inner),
    ]
  | Changelog({last, file, entries}) => [
      `${pad}${last ? "release" : "changelog"}${field("file", file)}`,
      ...entries->Array.flatMap(entry => [
        switch entry.version {
        | Some(version) => `${inner}version ${quote(version)}${field("date", entry.date)}`
        | None => `${inner}unreleased`
        },
        ...entry.changes->Array.map(change =>
          `${inner}  ${Changelog.kindName(change.kind)}${flag("breaking", change.breaking)}${flag(
              "unsaid",
              !change.said,
            )} ${quote(change.text)}`
        ),
      ]),
    ]
  | Extra({name, info, body}) => [`${pad}extra ${name} ${quote(info)}`, ...markdown(body, inner)]
  }
}

let write = nodes => nodes->Array.flatMap(n => lines(n, ""))->Array.join("\n")
