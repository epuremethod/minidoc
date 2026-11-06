// The `model` block: the tables of a database schema and the relations
// between them, drawn. The body is a grid of table names, a blank line, then
// the tables with their columns and the relations. The grid makes the layout,
// as it does for `states`. An end of a relation is drawn in crow's foot
// notation.

@@jsxConfig({version: 4, module_: "Draw"})

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
/** What joins two tables: the two ends of a relation, or a parent to its subclass. */
type join = Ends(ModelOp.arity, ModelOp.arity) | Parent
type relation = {from: string, to: string, join: join, way: Grid.way}

let nameLine = RegExp.fromString("^[\\p{L}\\p{N}_.\\-]+$", ~flags="u")
// A table's head line may name the tenant its rows carry: `Account #sonya`.
let headLine = RegExp.fromString("^([\\p{L}\\p{N}_.\\-]+)(?: #([\\p{L}\\p{N}_.\\-]+))?$", ~flags="u")
let columnLine = RegExp.fromString("^\\s+(\\S+)(?:\\s+(\\S+))?(?:\\s+(\\S.*?))?\\s*$")
let linkLine = RegExp.fromString("^(\\S+) +([^\\s-]*)--([^\\s-]*) +(\\S+)(?: +(.*))?$")
// A parent is written as the arrow reads, `Parent <- Child`, and drawn from
// the child to its parent.
let parentLine = RegExp.fromString("^(\\S+) +<- +(\\S+)(?: +(.*))?$")

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

let readLabel = (said, at) => {
  let (label, where, right, kind) = Grid.label(said->Option.getOr(""))
  kind->Option.forEach(kind => fail(`model: no kind called ${kind}, ${at}`))
  (label, where, right)
}

let readRelation = (line, at) =>
  switch RegExp.exec(linkLine, line) {
  | Some(m) =>
    let from = capture(m, 0)->Option.getOr("")
    let to = capture(m, 3)->Option.getOr("")
    let (label, where, right) = readLabel(capture(m, 4), at)
    let fromEnd = readEnd(leftEnds, capture(m, 1)->Option.getOr(""), at)
    let toEnd = readEnd(rightEnds, capture(m, 2)->Option.getOr(""), at)
    Some({from, to, join: Ends(fromEnd, toEnd), way: {from, to, label, at: where, right}})
  | None =>
    switch RegExp.exec(parentLine, line) {
    | Some(m) =>
      let parent = capture(m, 0)->Option.getOr("")
      let child = capture(m, 1)->Option.getOr("")
      let (label, where, right) = readLabel(capture(m, 2), at)
      Some({from: child, to: parent, join: Parent, way: {from: child, to: parent, label, at: where, right}})
    | None => None
    }
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
      switch readRelation(line, at) {
      | Some(relation) =>
        current := None
        relations->Array.push(relation)
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
        switch relation.join {
        | Ends(from, to) => ModelOp.Link({from, to, points: d.points, label: Grid.placedText(d)})
        | Parent => ModelOp.Parent({points: d.points, label: Grid.placedText(d)})
        }
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
let text = Draw.string

// An end is a marker drawn toward its table, which sits at x = 20. At the
// start of a line the same marker turns round. `reach` below is how far
// each one stands from the table: 20 less its leftmost point.
let shapes = (arity: ModelOp.arity) => {
  let crow = from => <path className="model__end" d={`M ${from} 8 L 20 1 M ${from} 8 L 20 15`} />
  let ring = x => <circle className="model__ring" cx=x cy="8" r="3.5" />
  switch arity {
  | ModelOp.One => Draw.null
  | ModelOp.Optional => ring("13")
  | ModelOp.More => crow("8")
  | ModelOp.Any =>
    <>
      {ring("5.5")}
      {crow("10")}
    </>
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

// A parent's end is a hollow triangle, as a class diagram draws it. It
// stands as far from its table as the longest crow's foot.
let parentId = "model-parent"
let parentReach = 14.
let parentMarker =
  <marker
    id=parentId
    viewBox="0 0 20 16"
    refX="20"
    refY="8"
    markerWidth="20"
    markerHeight="16"
    markerUnits="userSpaceOnUse"
    orient="auto"
  >
    <path className="model__parent" d="M 6 1 L 20 8 L 6 15 z" />
  </marker>

let marker = arity =>
  <marker
    id={markerId(arity)}
    viewBox="0 0 20 16"
    refX="20"
    refY="8"
    markerWidth="20"
    markerHeight="16"
    markerUnits="userSpaceOnUse"
    orient="auto-start-reverse"
  >
    {shapes(arity)}
  </marker>

/** The SVG of a database schema, painted from its operations. */
let draw = (drawing: drawing<ModelOp.t>) => {
  let pick = f => drawing.ops->Array.filterMap(f)->Draw.array
  let frame =
    drawing.ops
    ->Array.findMap(op =>
      switch op {
      | ModelOp.Frame(f) => Some(f)
      | _ => None
      }
    )
    ->Option.getOrThrow
  let used =
    drawing.ops
    ->Array.flatMap(op =>
      switch op {
      | ModelOp.Link({from, to}) => [from, to]
      | _ => []
      }
    )
    ->Array.filter(a => a != ModelOp.One)
  let used =
    [ModelOp.Optional, ModelOp.More, ModelOp.Any]->Array.filter(a => used->Array.includes(a))
  let parents = drawing.ops->Array.some(op =>
    switch op {
    | ModelOp.Parent(_) => true
    | _ => false
    }
  )
  let tips =
    used == [] && !parents
      ? Draw.null
      : <defs>
          {used->Array.map(marker)->Draw.array}
          {parents ? parentMarker : Draw.null}
        </defs>
  let end = arity => arity == ModelOp.One ? None : Some(`url(#${markerId(arity)})`)
  let links = pick(op =>
    switch op {
    | ModelOp.Link({from, to, points: [x0, y0, x1, y1, x2, y2, x3, y3]}) =>
      let (s0x, s0y) = stub(x0, y0, x1, y1, reach(from) *. straight)
      let (s3x, s3y) = stub(x3, y3, x2, y2, reach(to) *. straight)
      Some(
        <path
          className="model__link"
          markerStart=?{end(from)}
          markerEnd=?{end(to)}
          d={`M ${n(x0)} ${n(y0)} L ${n(s0x)} ${n(s0y)} C ${n(x1)} ${n(y1)}, ${n(x2)} ${n(y2)}, ${n(
              s3x,
            )} ${n(s3y)} L ${n(x3)} ${n(y3)}`}
          dataEnds={`${arityName(from)} ${arityName(to)}`}
        />,
      )
    | ModelOp.Parent({points: [x0, y0, x1, y1, x2, y2, x3, y3]}) =>
      let (s3x, s3y) = stub(x3, y3, x2, y2, parentReach *. straight)
      Some(
        <path
          className="model__link"
          markerEnd={`url(#${parentId})`}
          d={`M ${n(x0)} ${n(y0)} C ${n(x1)} ${n(y1)}, ${n(x2)} ${n(y2)}, ${n(s3x)} ${n(s3y)} L ${n(
              x3,
            )} ${n(y3)}`}
          dataParent=""
        />,
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
      let modifier =
        tenant->Option.mapOr("", t =>
          ` model__table--tenant-${Int.toString(tenants->Array.indexOf(t))}`
        )
      Some(
        <g className={`model__table${modifier}`}>
          <rect x={n(x)} y={n(y)} width={n(width)} height={n(height)} />
          <text className="model__name" x={n(left)} y={n(y +. headHeight /. 2. +. 4.)}>
            {text(name)}
          </text>
          {switch tenant {
          | Some(t) =>
            <text
              className="model__tenant"
              x={n(x +. width -. pad)}
              y={n(y +. headHeight /. 2. +. 4.)}
              textAnchor="end"
            >
              {text(t)}
            </text>
          | None => Draw.null
          }}
          {columns == []
            ? Draw.null
            : <line
                className="model__rule"
                x1={n(x)}
                y1={n(y +. headHeight)}
                x2={n(x +. width)}
                y2={n(y +. headHeight)}
              />}
          {columns
          ->Array.map(c =>
            <>
              <text className="model__column" x={n(left)} y={n(c.y)}> {text(c.name)} </text>
              {switch c.kind {
              | Some(k) => <text className="model__type" x={n(kindX)} y={n(c.y)}> {text(k)} </text>
              | None => Draw.null
              }}
              {switch c.value {
              | Some(v) =>
                <text className="model__value" x={n(valueX)} y={n(c.y)}> {text(v)} </text>
              | None => Draw.null
              }}
            </>
          )
          ->Draw.array}
        </g>,
      )
    | _ => None
    }
  )
  let notes = pick(op =>
    switch op {
    | ModelOp.Link({label: Some(({x, y, text: said}, anchor))})
    | ModelOp.Parent({label: Some(({x, y, text: said}, anchor))}) =>
      Some(<text className="model__label" x={n(x)} y={n(y)} textAnchor=anchor> {text(said)} </text>)
    | _ => None
    }
  )
  <figure className="model">
    <svg
      className="model__svg"
      viewBox={`${n(frame.left)} ${n(frame.top)} ${n(frame.width)} ${n(frame.height)}`}
      width={n(frame.width)}
      height={n(frame.height)}
      role="img"
      ariaLabel={drawing.caption->Option.getOr("A database schema")}
    >
      tips
      links
      tables
      notes
    </svg>
    {switch drawing.caption {
    | Some(c) =>
      <figcaption className="model__caption">
        <span className="model__title"> {text(c)} </span>
      </figcaption>
    | None => Draw.null
    }}
  </figure>
}
