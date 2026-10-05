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
  | Head({kind, x, y, width, height, name}) => [`${pad}head ${kind} ${nums([x, y, width, height])} ${quote(name)}`]
  | Life({x, top, bottom}) => [`${pad}life ${nums([x, top, bottom])}`]
  | Message({from, to, y, refused, label}) => [
      `${pad}${refused ? "refused" : "message"} ${nums([from, to, y])}`,
      ...label->Option.mapOr([], l => [`${pad}  label ${nums([l.x, l.y])} ${quote(l.text)}`]),
    ]
  | State({x, y, width, height, text}) => [`${pad}state ${nums([x, y, width, height])} ${quote(text)}`]
  }

let statesOp = (op: StatesOp.t, pad) =>
  switch op {
  | Frame({left, top, width, height}) => [`${pad}frame ${nums([left, top, width, height])}`]
  | Box({kind, x, y, width, height, name}) => [`${pad}box ${kind} ${nums([x, y, width, height])} ${quote(name)}`]
  | Move({kind, points, label}) => [
      `${pad}move${kind->Option.mapOr("", k => ` ${k}`)} ${nums(points)}`,
      ...label->Option.mapOr([], ((l, anchor)) => [
        `${pad}  label ${nums([l.x, l.y])} ${anchor} ${quote(l.text)}`,
      ]),
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
  | Field(label) => [`${pad}field ${quote(label)}`]
  }

let rec lines = (node, pad) => {
  let inner = `${pad}  `
  let children = nodes => nodes->Array.flatMap(n => lines(n, inner))
  switch node {
  | Markdown(text) => markdown(text, pad)
  | Callout({name, label, children: c}) => [`${pad}callout ${name} ${quote(label)}`, ...children(c)]
  | Quote({author, date, children: c}) => [`${pad}quote${field("author", author)}${field("date", date)}`, ...children(c)]
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
  | Dialog({owner, title, widgets}) => [
      `${pad}ui-dialog${owner->Option.mapOr("", ((key, label)) => ` owner ${key} ${quote(label)}`)}${field(
          "title",
          title,
        )}`,
      ...widgets->Array.flatMap(w => widget(w, inner)),
    ]
  | Screens({caption, children: c}) => [`${pad}ui-flow${field("caption", caption)}`, ...children(c)]
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
  | Extra({name, info, body}) => [`${pad}extra ${name} ${quote(info)}`, ...markdown(body, inner)]
  }
}

let write = nodes => nodes->Array.flatMap(n => lines(n, ""))->Array.join("\n")
