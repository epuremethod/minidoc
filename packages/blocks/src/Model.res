// The `model` block: the tables of a database schema and the relations
// between them, drawn. The body is a grid of table names, a blank line, then
// the tables with their columns and the relations. The grid makes the layout,
// as it does for `states`. An end of a relation is drawn in crow's foot
// notation.

open Node

let fail = Html.fail
let width = Sequence.width
let capture = Sequence.capture

let headHeight = 30.
let rowHeight = 22.
let foot = 6.
let pad = 12.
let gap = 14.
// Two columns of tables stand further apart than two of states: each end of
// a line carries a mark, and the line between them must still show.
let across = 96.
// The baseline of a row's text, from the top of its row.
let baseline = 15.

type table = {name: string, tenant: option<string>, columns: array<(string, option<string>, option<string>)>}
type relation = {from: string, to: string, fromEnd: ModelOp.arity, toEnd: ModelOp.arity, way: Grid.way}

let nameLine = RegExp.fromString("^[\\p{L}\\p{N}_.\\-]+$", ~flags="u")
// A table's head line may name the tenant its rows carry: `Account #sonya`.
let headLine = RegExp.fromString("^([\\p{L}\\p{N}_.\\-]+)(?: #([\\p{L}\\p{N}_.\\-]+))?$", ~flags="u")
let columnLine = RegExp.fromString("^\\s+(\\S+)(?:\\s+(\\S+))?(?:\\s+(\\S.*?))?\\s*$")
let linkLine = RegExp.fromString("^(\\S+) +([^\\s-]*)--([^\\s-]*) +(\\S+)(?: +(.*))?$")

// An end is written as it is drawn, read from its table toward the line: a
// ring for none, a crow's foot for more than one, nothing for exactly one.
// The tokens of mermaid's entity relations are read too, and drawn in the
// same four ends.
let leftEnds = [
  ("", ModelOp.One),
  ("o", ModelOp.Optional),
  (">", ModelOp.More),
  (">o", ModelOp.Any),
  ("||", ModelOp.One),
  ("|o", ModelOp.Optional),
  ("}|", ModelOp.More),
  ("}o", ModelOp.Any),
]
let rightEnds = [
  ("", ModelOp.One),
  ("o", ModelOp.Optional),
  ("<", ModelOp.More),
  ("o<", ModelOp.Any),
  ("||", ModelOp.One),
  ("o|", ModelOp.Optional),
  ("|{", ModelOp.More),
  ("o{", ModelOp.Any),
]

let arityName = (arity: ModelOp.arity) =>
  switch arity {
  | ModelOp.One => "one"
  | ModelOp.Optional => "optional"
  | ModelOp.More => "more"
  | ModelOp.Any => "any"
  }

let readEnd = (ends, said, at) =>
  switch ends->Array.find(((token, _)) => token == said) {
  | Some((_, arity)) => arity
  | None => fail(`model: cannot read the end "${said}", ${at}`)
  }

let readText = text => {
  let rows: array<array<option<string>>> = []
  let tables: array<table> = []
  let relations = []
  let past = ref(false)
  let current = ref(None)
  text
  ->String.split("\n")
  ->Array.forEachWithIndex((raw, index) => {
    let line = String.trimEnd(raw)
    let at = `line ${Int.toString(index + 1)}`
    if String.trim(line) == "" {
      if Array.length(rows) > 0 {
        past := true
      }
    } else if String.startsWith(String.trim(line), "#") {
      ()
    } else if !past.contents {
      let cells = Grid.cells(line)
      if !(cells->Array.every(c => c->Option.mapOr(true, c => RegExp.test(nameLine, c)))) {
        fail(`model: cannot read the grid at ${at}`)
      }
      rows->Array.push(cells)
    } else if String.startsWith(line, " ") || String.startsWith(line, "\t") {
      switch (current.contents, RegExp.exec(columnLine, line)) {
      | (None, _) => fail(`model: a column outside a table, ${at}`)
      | (_, None) => fail(`model: cannot read the column at ${at}`)
      | (Some(table: table), Some(m)) =>
        table.columns->Array.push((capture(m, 0)->Option.getOr(""), capture(m, 1), capture(m, 2)))
      }
    } else {
      switch RegExp.exec(linkLine, line) {
      | Some(m) =>
        current := None
        let from = capture(m, 0)->Option.getOr("")
        let to = capture(m, 3)->Option.getOr("")
        let (label, where, right, kind) = Grid.label(capture(m, 4)->Option.getOr(""))
        kind->Option.forEach(kind => fail(`model: no kind called ${kind}, ${at}`))
        relations->Array.push({
          from,
          to,
          fromEnd: readEnd(leftEnds, capture(m, 1)->Option.getOr(""), at),
          toEnd: readEnd(rightEnds, capture(m, 2)->Option.getOr(""), at),
          way: {from, to, label, at: where, right},
        })
      | None =>
        switch RegExp.exec(headLine, line) {
        | None => fail(`model: cannot read ${at}`)
        | Some(m) =>
          let name = capture(m, 0)->Option.getOr("")
          if !(rows->Array.flat->Array.includes(Some(name))) {
            fail(`model: no table called ${name} in the grid, ${at}`)
          }
          if tables->Array.some(t => t.name == name) {
            fail(`model: ${name} is described twice, ${at}`)
          }
          let table = {name, tenant: capture(m, 1), columns: []}
          tables->Array.push(table)
          current := Some(table)
        }
      }
    }
  })
  if Array.length(rows) == 0 {
    fail("model: the grid is empty")
  }
  // A relation names two tables, and only the grid declares them.
  let placed = rows->Array.flat->Array.filterMap(c => c)
  relations->Array.forEach(relation =>
    [relation.from, relation.to]->Array.forEach(end =>
      if !(placed->Array.includes(end)) {
        fail(`model: no table called ${end}`)
      }
    )
  )
  (rows, tables, relations)
}

let most = values => values == [] ? 0. : Math.maxMany(values)

// The widths a table's three text columns take: its column names, their
// types, and the values they show.
type widths = {names: float, kinds: float, values: float}

let measure = (table: table) => {
  let names = table.columns->Array.map(((name, _, _)) => width(name, 12.))->most
  let kinds = table.columns->Array.filterMap(((_, kind, _)) => kind)->Array.map(k => width(k, 12.))->most
  let values = table.columns->Array.filterMap(((_, _, value)) => value)->Array.map(v => width(v, 12.))->most
  let inner = names +. (kinds > 0. ? gap +. kinds : 0.) +. (values > 0. ? gap +. values : 0.)
  let tag = table.tenant->Option.mapOr(0., t => gap +. width(t, 11.))
  let w = Math.max(width(table.name, 13.) +. tag, inner) +. pad *. 2.
  let rows = Array.length(table.columns)
  let h = rows == 0 ? headHeight : headHeight +. Int.toFloat(rows) *. rowHeight +. foot
  ({names, kinds, values}, w, h)
}

/** The drawing of a database schema: its operations, placed. */
let read = (text, caption): drawing<ModelOp.t> => {
  let (rows, tables, relations) = readText(text)
  let described = name =>
    tables->Array.find(t => t.name == name)->Option.getOr({name, tenant: None, columns: []})
  let (boxes, right) = Grid.place(
    ~across,
    rows->Array.map(row =>
      row->Array.map(c =>
        c->Option.map((name): Grid.box<(table, widths)> => {
          let table = described(name)
          let (widths, w, h) = measure(table)
          {name, w, h, data: (table, widths)}
        })
      )
    ),
  )
  let drawn = Grid.route(relations->Array.map(r => r.way), boxes)
  {
    ops: [
      ModelOp.Frame(Grid.frame(boxes, drawn, right)),
      ...drawn->Array.mapWithIndex((d, index) => {
        let relation = relations->Array.getUnsafe(index)
        ModelOp.Link({from: relation.fromEnd, to: relation.toEnd, points: d.points, label: Grid.placedText(d)})
      }),
      ...boxes->Array.map(b => {
        let (table, widths) = b.data
        let kindX = b.x +. pad +. widths.names +. gap
        ModelOp.Table({
          x: b.x,
          y: b.y,
          width: b.w,
          height: b.h,
          name: b.name,
          tenant: table.tenant,
          kindX,
          valueX: widths.kinds > 0. ? kindX +. widths.kinds +. gap : kindX,
          columns: table.columns->Array.mapWithIndex(((name, kind, value), index): ModelOp.column => {
            y: b.y +. headHeight +. Int.toFloat(index) *. rowHeight +. baseline,
            name,
            kind,
            value,
          }),
        })
      }),
    ],
    caption,
    keys: [],
  }
}

let n = Float.toString
let escape = Html.escape

// An end is a marker drawn toward its table, which sits at x = 20. At the
// start of a line the same marker turns round. `reach` below is how far
// each one stands from the table: 20 less its leftmost point.
let shapes = (arity: ModelOp.arity) => {
  let crow = from => `<path class="model__end" d="M ${from} 8 L 20 1 M ${from} 8 L 20 15" />`
  let ring = x => `<circle class="model__ring" cx="${x}" cy="8" r="3.5" />`
  switch arity {
  | ModelOp.One => ""
  | ModelOp.Optional => ring("13")
  | ModelOp.More => crow("8")
  | ModelOp.Any => ring("5.5") ++ crow("10")
  }
}

// A mark is drawn along the line where it meets its table. The line runs
// straight from the table under its mark, then curves: else the curve still
// bends under the mark, and the mark stands beside the line. The straight
// piece is seven tenths of the mark: a curve leaves a straight line so
// gently that it looks to start later than it does. The control points lie
// further along the same normal, so the curve leaves the straight piece
// without a corner.
let straight = 0.7

let reach = (arity: ModelOp.arity) =>
  switch arity {
  | ModelOp.One => 0.
  | ModelOp.Optional => 10.5
  | ModelOp.More => 12.
  | ModelOp.Any => 18.
  }

let stub = (x, y, towardX, towardY, length) => {
  let run = Math.hypot(towardX -. x, towardY -. y)
  run == 0.
    ? (x, y)
    : (x +. (towardX -. x) /. run *. length, y +. (towardY -. y) /. run *. length)
}

let markerId = arity => `model-${arityName(arity)}`

let marker = arity =>
  `<marker id="${markerId(arity)}" viewBox="0 0 20 16" refX="20" refY="8" markerWidth="20" markerHeight="16" markerUnits="userSpaceOnUse" orient="auto-start-reverse">${shapes(
      arity,
    )}</marker>`

/** The SVG of a database schema, painted from its operations. */
let render = (drawing: drawing<ModelOp.t>) => {
  let pick = f => drawing.ops->Array.filterMap(f)->Array.join("")
  let frame = drawing.ops->Array.findMap(op =>
    switch op {
    | ModelOp.Frame(f) => Some(f)
    | _ => None
    }
  )->Option.getOrThrow
  let used = drawing.ops->Array.flatMap(op =>
    switch op {
    | ModelOp.Link({from, to}) => [from, to]
    | _ => []
    }
  )->Array.filter(a => a != ModelOp.One)
  let used = [ModelOp.Optional, ModelOp.More, ModelOp.Any]->Array.filter(a => used->Array.includes(a))
  let tips = used == [] ? "" : `<defs>${used->Array.map(marker)->Array.join("")}</defs>`
  let end = (attribute, arity) => arity == ModelOp.One ? "" : ` ${attribute}="url(#${markerId(arity)})"`
  let links = pick(op =>
    switch op {
    | ModelOp.Link({from, to, points: [x0, y0, x1, y1, x2, y2, x3, y3]}) =>
      let (s0x, s0y) = stub(x0, y0, x1, y1, reach(from) *. straight)
      let (s3x, s3y) = stub(x3, y3, x2, y2, reach(to) *. straight)
      Some(
        `<path class="model__link"${end("marker-start", from)}${end("marker-end", to)} d="M ${n(x0)} ${n(y0)} L ${n(s0x)} ${n(s0y)} C ${n(x1)} ${n(y1)}, ${n(x2)} ${n(y2)}, ${n(s3x)} ${n(s3y)} L ${n(x3)} ${n(y3)}" data-ends="${arityName(from)} ${arityName(to)}" />`,
      )
    | _ => None
    }
  )
  // A tenant takes the index of its first table, counted among tenants.
  let tenants = drawing.ops->Array.reduce([], (seen, op) =>
    switch op {
    | ModelOp.Table({tenant: Some(t)}) if !(seen->Array.includes(t)) => [...seen, t]
    | _ => seen
    }
  )
  let tables = pick(op =>
    switch op {
    | ModelOp.Table({x, y, width, height, name, tenant, kindX, valueX, columns}) =>
      let left = x +. pad
      let (tone, tag) = switch tenant {
      | Some(t) => (
          ` model__table--tenant-${Int.toString(tenants->Array.indexOf(t))}`,
          `<text class="model__tenant" text-anchor="end" x="${n(x +. width -. pad)}" y="${n(y +. headHeight /. 2. +. 4.)}">${escape(t)}</text>`,
        )
      | None => ("", "")
      }
      let rule =
        columns == []
          ? ""
          : `<line class="model__rule" x1="${n(x)}" y1="${n(y +. headHeight)}" x2="${n(x +. width)}" y2="${n(y +. headHeight)}" />`
      let rows = columns->Array.map(c =>
        [
          `<text class="model__column" x="${n(left)}" y="${n(c.y)}">${escape(c.name)}</text>`,
          c.kind->Option.mapOr("", k => `<text class="model__type" x="${n(kindX)}" y="${n(c.y)}">${escape(k)}</text>`),
          c.value->Option.mapOr("", v => `<text class="model__value" x="${n(valueX)}" y="${n(c.y)}">${escape(v)}</text>`),
        ]->Array.join("")
      )->Array.join("")
      Some(
        `<g class="model__table${tone}"><rect x="${n(x)}" y="${n(y)}" width="${n(width)}" height="${n(height)}" /><text class="model__name" x="${n(left)}" y="${n(y +. headHeight /. 2. +. 4.)}">${escape(name)}</text>${tag}${rule}${rows}</g>`,
      )
    | _ => None
    }
  )
  let notes = pick(op =>
    switch op {
    | ModelOp.Link({label: Some(({x, y, text}, anchor))}) =>
      Some(`<text class="model__label" text-anchor="${anchor}" x="${n(x)}" y="${n(y)}">${escape(text)}</text>`)
    | _ => None
    }
  )
  let label = drawing.caption->Option.getOr("A database schema")
  let under = drawing.caption->Option.mapOr("", c =>
    `<figcaption class="model__caption"><span class="model__title">${escape(c)}</span></figcaption>`
  )
  `<figure class="model"><svg class="model__svg" viewBox="${n(frame.left)} ${n(frame.top)} ${n(frame.width)} ${n(frame.height)}" width="${n(frame.width)}" height="${n(frame.height)}" role="img" aria-label="${escape(label)}">${tips}${links}${tables}${notes}</svg>${under}</figure>`
}
