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
// A table's text starts 12px from its left side and ends 16px from its
// right side, where a tenant or a value would else touch the edge.
let pad = 12.
let padRight = 16.
let gap = 14.
// Two columns of tables stand further apart than two of states: each end of
// a line carries a mark, and the line between them must still show.
let across = 96.
// The baseline of a row's text, from the top of its row.
let baseline = 15.

// A text of a column and the colour it may take.
type part = (string, option<string>)
// A group starts before the column at its index: its name, if any, and the
// line it was written on.
type group = {before: int, name: option<part>, at: string}
type table = {
  name: string,
  tenant: option<string>,
  columns: array<(part, option<part>, option<part>)>,
  groups: array<group>,
}
/** What joins two tables: the two ends of a relation, a parent to its subclass, or a process. */
type join = Ends(ModelOp.arity, ModelOp.arity) | Parent | Process
type relation = {from: string, to: string, join: join, way: Grid.way, color: option<string>}

let nameLine = RegExp.fromString("^[\\p{L}\\p{N}_.\\-]+$", ~flags="u")
// A table's head line may name the tenant its rows carry: `Account #sonya`.
let headLine = RegExp.fromString("^([\\p{L}\\p{N}_.\\-]+)(?: #([\\p{L}\\p{N}_.\\-]+))?$", ~flags="u")
// A column's name and type are words, braced or plain; its value is the rest
// of the line, or a word in braces.
// A line of dashes groups the columns under it: `--- Accès`, or bare `---`.
let groupLine = RegExp.fromString("^\\s+-{3,}(?:\\s+(\\S.*?))?\\s*$")
let columnLine = RegExp.fromString("^\\s+(\\{[^}]*\\}|\\S+)(?:\\s+(\\{[^}]*\\}|\\S+))?(?:\\s+(\\S.*?))?\\s*$")
// A table in braces holds spaces and its attributes: `{Order line, #eu}`.
let name = "(\\{[^}]*\\}|\\S+)"
let linkLine = RegExp.fromString(`^${name} +([^\\s-]*)--([^\\s-]*) +${name}(?: +(.*))?$`)
// A parent is written as the arrow reads, `Parent <- Child`, and drawn from
// the child to its parent.
let parentLine = RegExp.fromString(`^${name} +<- +${name}(?: +(.*))?$`)
// A process, such as a copy, is not a link in the data. It is written as it
// is drawn, dots then a tip: `Definition ..> Workflow`.
let processLine = RegExp.fromString(`^${name} +\\.\\.> +${name}(?: +(.*))?$`)

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
  let (label, where, right, _, color) = Braced.label(said->Option.getOr(""), ~block="model", ~at, ~kinds=Dict.make())
  (label, where, right, color)
}

// A table as written, with its tenant and its colour, kept with the marks
// of its other mentions.
let named = (marks, word, at) => {
  let {text, attributes}: Braced.t = Braced.read(word, ~block="model", ~at)
  marks->Braced.merge(
    text,
    Braced.marks(text, attributes, ~block="model", ~at, ~tenant=true),
    ~block="model",
    ~at,
  )
  text
}

let readRelation = (marks, line, at) => {
  let named = word => named(marks, word->Option.getOr(""), at)
  switch RegExp.exec(linkLine, line) {
  | Some(m) =>
    let from = named(capture(m, 0))
    let to = named(capture(m, 3))
    let (label, where, right, color) = readLabel(capture(m, 4), at)
    let fromEnd = readEnd(leftEnds, capture(m, 1)->Option.getOr(""), at)
    let toEnd = readEnd(rightEnds, capture(m, 2)->Option.getOr(""), at)
    Some({from, to, join: Ends(fromEnd, toEnd), way: {from, to, label, at: where, right}, color})
  | None =>
    switch RegExp.exec(parentLine, line) {
    | Some(m) =>
      let parent = named(capture(m, 0))
      let child = named(capture(m, 1))
      let (label, where, right, color) = readLabel(capture(m, 2), at)
      Some({
        from: child,
        to: parent,
        join: Parent,
        way: {from: child, to: parent, label, at: where, right},
        color,
      })
    | None =>
      switch RegExp.exec(processLine, line) {
      | Some(m) =>
        let from = named(capture(m, 0))
        let to = named(capture(m, 1))
        let (label, where, right, color) = readLabel(capture(m, 2), at)
        Some({from, to, join: Process, way: {from, to, label, at: where, right}, color})
      | None => None
      }
    }
  }
}

let readText = text => {
  let rows: array<array<option<string>>> = []
  let tables: array<table> = []
  let relations = []
  let past = ref(false)
  let current = ref(None)
  let marks = Dict.make()
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
      rows->Array.push(
        Braced.words(line, ~block="model", ~at)->Array.map(c =>
          if c == "." {
            None
          } else if String.startsWith(c, "{") || RegExp.test(nameLine, c) {
            Some(named(marks, c, at))
          } else {
            fail(`model: cannot read the grid at ${at}`)
          }
        ),
      )
    } else if String.startsWith(line, " ") || String.startsWith(line, "\t") {
      // A part in braces holds spaces and takes a colour, as any word in braces does.
      let part = word => {
        let {text, attributes}: Braced.t = Braced.read(word, ~block="model", ~at)
        (text, Braced.marks(text, attributes, ~block="model", ~at).color)
      }
      switch (current.contents, RegExp.exec(groupLine, line), RegExp.exec(columnLine, line)) {
      | (None, _, _) => fail(`model: a column outside a table, ${at}`)
      | (Some(table: table), Some(m), _) =>
        table.groups->Array.push({
          before: Array.length(table.columns),
          name: capture(m, 0)->Option.map(part),
          at,
        })
      | (_, None, None) => fail(`model: cannot read the column at ${at}`)
      | (Some(table: table), None, Some(m)) =>
        table.columns->Array.push((
          part(capture(m, 0)->Option.getOr("")),
          capture(m, 1)->Option.map(part),
          capture(m, 2)->Option.map(part),
        ))
      }
    } else {
      switch readRelation(marks, line, at) {
      | Some(relation) =>
        current := None
        relations->Array.push(relation)
      | None =>
        // A head line is a name and its tenant, `Order #eu`, or a name in
        // braces with its attributes, `{Order, #eu, color teal}`.
        let head = if String.startsWith(line, "{") && String.endsWith(line, "}") {
          Some(named(marks, line, at))
        } else {
          RegExp.exec(headLine, line)->Option.map(m => {
            let name = capture(m, 0)->Option.getOr("")
            marks->Braced.merge(name, {...Braced.none, tenant: capture(m, 1)}, ~block="model", ~at)
            name
          })
        }
        switch head {
        | None => fail(`model: cannot read ${at}`)
        | Some(name) =>
          if !(rows->Array.flat->Array.includes(Some(name))) {
            fail(`model: no table called ${name} in the grid, ${at}`)
          }
          if tables->Array.some(t => t.name == name) {
            fail(`model: ${name} is described twice, ${at}`)
          }
          let table = {name, tenant: None, columns: [], groups: []}
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
  // A table's tenant and colour come from any of its mentions. Without a
  // colour, a tenant gives its own: the hue its name hashes to.
  // A group holds at least one column: the next group, or the table's end,
  // comes after a column of its own.
  tables->Array.forEach(t =>
    t.groups->Array.forEachWithIndex((g, index) => {
      let next = t.groups->Array.get(index + 1)->Option.mapOr(Array.length(t.columns), g => g.before)
      if next <= g.before {
        fail(`model: a group has no column, ${g.at}`)
      }
    })
  )
  let tables = tables->Array.map(t => {...t, tenant: marks->Dict.get(t.name)->Option.flatMap(m => m.tenant)})
  (rows, tables, relations, marks)
}

let most = values => values == [] ? 0. : Math.maxMany(values)

// A group's row is a line alone. Its name sits at the right of its first
// column's row, on the same baseline.
let groupHeight = 8.
// A group's name is bold: it runs a tenth wider than the measure says.
let groupWidth = text => width(text, 13.) *. 1.1

/** The top of each column's row and of each group's row, under a table's head. */
let rows = (table: table) => {
  let top = ref(headHeight)
  let columnTops = []
  let groupTops = []
  table.columns->Array.forEachWithIndex((_, index) => {
    table.groups->Array.forEach(g =>
      if g.before == index {
        groupTops->Array.push(top.contents)
        top := top.contents +. groupHeight
      }
    )
    columnTops->Array.push(top.contents)
    top := top.contents +. rowHeight
  })
  (columnTops, groupTops, top.contents)
}

// The widths a table's three text columns take: its column names, their
// types, and the values they show.
type widths = {names: float, kinds: float, values: float}

let measure = (table: table) => {
  let names = table.columns->Array.map((((name, _), _, _)) => width(name, 12.))->most
  let kinds = table.columns->Array.filterMap(((_, kind, _)) => kind)->Array.map(((k, _)) => width(k, 12.))->most
  let values = table.columns->Array.filterMap(((_, _, value)) => value)->Array.map(((v, _)) => width(v, 12.))->most
  // A group's name shares its first column's row: the row's text, a gap,
  // and the name.
  let kindX = names +. gap
  let valueX = kindX +. (kinds > 0. ? kinds +. gap : 0.)
  let groups =
    table.groups
    ->Array.filterMap(g =>
      g.name->Option.map(((name, _)) => {
        let row = switch table.columns->Array.get(g.before) {
        | Some((_, _, Some((v, _)))) => valueX +. width(v, 12.)
        | Some((_, Some((k, _)), None)) => kindX +. width(k, 12.)
        | Some(((c, _), None, None)) => width(c, 12.)
        | None => 0.
        }
        row +. gap +. groupWidth(name)
      })
    )
    ->most
  let inner = Math.max(names +. (kinds > 0. ? gap +. kinds : 0.) +. (values > 0. ? gap +. values : 0.), groups)
  let tag = table.tenant->Option.mapOr(0., t => gap +. width(t, 11.))
  let w = Math.max(width(table.name, 13.) +. tag, inner) +. pad +. padRight
  let (_, _, bottom) = rows(table)
  let h = table.columns == [] ? headHeight : bottom +. foot
  ({names, kinds, values}, w, h)
}

/** The drawing of a database schema: its operations, placed. */
let read = (text, caption): drawing<ModelOp.t> => {
  let (grid, tables, relations, marks) = readText(text)
  let placed = grid->Array.flat->Array.filterMap(c => c)
  let colorOf = name =>
    marks
    ->Dict.get(name)
    ->Option.flatMap(m => m.color->Option.orElse(m.tenant->Option.map(Braced.hue)))
  let described = name =>
    tables
    ->Array.find(t => t.name == name)
    ->Option.getOr({
      name,
      tenant: marks->Dict.get(name)->Option.flatMap(m => m.tenant),
      columns: [],
      groups: [],
    })
  let (boxes, right) = Grid.place(
    ~across,
    grid->Array.map(row =>
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
        let {color} = relation
        let label = Grid.placedText(d)
        switch relation.join {
        | Ends(from, to) => ModelOp.Link({from, to, points: d.points, label, color})
        | Parent => ModelOp.Parent({points: d.points, label, color})
        | Process => ModelOp.Process({points: d.points, label, color})
        }
      }),
      ...boxes->Array.map(b => {
        let (table, widths) = b.data
        let kindX = b.x +. pad +. widths.names +. gap
        let (columnTops, groupTops, _) = rows(table)
        ModelOp.Table({
          x: b.x,
          y: b.y,
          width: b.w,
          height: b.h,
          name: b.name,
          tenant: table.tenant,
          color: colorOf(b.name),
          kindX,
          valueX: widths.kinds > 0. ? kindX +. widths.kinds +. gap : kindX,
          columns: table.columns->Array.mapWithIndex((((name, nameColor), kind, value), index): ModelOp.column => {
            y: b.y +. columnTops->Array.getUnsafe(index) +. baseline,
            name,
            nameColor,
            kind: kind->Option.map(Pair.first),
            kindColor: kind->Option.flatMap(Pair.second),
            value: value->Option.map(Pair.first),
            valueColor: value->Option.flatMap(Pair.second),
          }),
          // A group named after a table of the drawing holds what it
          // inherits from it, and its rows take that table's hue; its own
          // colour comes first.
          // A group first in the table draws no line: the head's rule is
          // right above it.
          groups: table.groups->Array.mapWithIndex((g, index): ModelOp.group => {
            let top = b.y +. groupTops->Array.getUnsafe(index)
            {
              y: top,
              name: g.name->Option.map(Pair.first),
              color: g.name->Option.flatMap(((text, color)) =>
                color->Option.orElse(placed->Array.includes(text) ? colorOf(text) : None)
              ),
              from: g.before == 0 ? None : Some(b.x),
            }
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

let stub = Grid.stub

// An end takes no colour from the line that uses it, so a coloured line
// gets ends of its own hue: their ids end in `-hue-<hue>`.
let hued = (id, hue) => `${id}${hue->Option.mapOr("", h => `-hue-${h}`)}`
let markerId = (arity, hue) => hued(`model-${arityName(arity)}`, hue)

// A parent's end is a hollow triangle, as a class diagram draws it. It
// stands as far from its table as the longest crow's foot.
let parentId = "model-parent"
let parentReach = 14.
let parentMarker = hue =>
  <marker
    id={hued(parentId, hue)}
    style=?{hue->Option.map(Braced.tone)}
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

// A process ends in the filled tip of a sequence's message.
let processId = "model-process"
let processReach = 14.
let processMarker = hue =>
  <marker
    id={hued(processId, hue)}
    style=?{hue->Option.map(Braced.tone)}
    viewBox="0 0 14 10"
    refX="13"
    refY="5"
    markerWidth="14"
    markerHeight="10"
    markerUnits="userSpaceOnUse"
    orient="auto"
  >
    <path className="model__process" d="M 0 0 L 14 5 L 0 10 L 3.8 5 z" />
  </marker>

let marker = ((arity, hue)) =>
  <marker
    id={markerId(arity, hue)}
    style=?{hue->Option.map(Braced.tone)}
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
  // The ends each line needs, in its hue.
  let used =
    drawing.ops
    ->Array.flatMap(op =>
      switch op {
      | ModelOp.Link({from, to, color}) =>
        [from, to]->Array.filter(a => a != ModelOp.One)->Array.map(a => (a, color))
      | _ => []
      }
    )
    ->Sequence.unique
  let parents =
    drawing.ops
    ->Array.filterMap(op =>
      switch op {
      | ModelOp.Parent({color}) => Some(color)
      | _ => None
      }
    )
    ->Sequence.unique
  let processes =
    drawing.ops
    ->Array.filterMap(op =>
      switch op {
      | ModelOp.Process({color}) => Some(color)
      | _ => None
      }
    )
    ->Sequence.unique
  let tips =
    used == [] && parents == [] && processes == []
      ? Draw.null
      : <defs>
          {used->Array.map(marker)->Draw.array}
          {parents->Array.map(parentMarker)->Draw.array}
          {processes->Array.map(processMarker)->Draw.array}
        </defs>
  let end = (arity, color) => arity == ModelOp.One ? None : Some(`url(#${markerId(arity, color)})`)
  let links = pick(op =>
    switch op {
    | ModelOp.Link({from, to, color, points: [x0, y0, x1, y1, x2, y2, x3, y3]}) =>
      let (s0x, s0y) = stub(x0, y0, x1, y1, reach(from) *. straight)
      let (s3x, s3y) = stub(x3, y3, x2, y2, reach(to) *. straight)
      Some(
        <path
          className="model__link"
          style=?{color->Option.map(Braced.tone)}
          markerStart=?{end(from, color)}
          markerEnd=?{end(to, color)}
          d={`M ${n(x0)} ${n(y0)} L ${n(s0x)} ${n(s0y)} C ${n(x1)} ${n(y1)}, ${n(x2)} ${n(y2)}, ${n(
              s3x,
            )} ${n(s3y)} L ${n(x3)} ${n(y3)}`}
          dataEnds={`${arityName(from)} ${arityName(to)}`}
        />,
      )
    | ModelOp.Parent({color, points: [x0, y0, x1, y1, x2, y2, x3, y3]}) =>
      let (s3x, s3y) = stub(x3, y3, x2, y2, parentReach *. straight)
      Some(
        <path
          className="model__link"
          style=?{color->Option.map(Braced.tone)}
          markerEnd={`url(#${hued(parentId, color)})`}
          d={`M ${n(x0)} ${n(y0)} C ${n(x1)} ${n(y1)}, ${n(x2)} ${n(y2)}, ${n(s3x)} ${n(s3y)} L ${n(
              x3,
            )} ${n(y3)}`}
          dataParent=""
        />,
      )
    | ModelOp.Process({color, points: [x0, y0, x1, y1, x2, y2, x3, y3]}) =>
      let (s3x, s3y) = stub(x3, y3, x2, y2, processReach *. straight)
      Some(
        <path
          className="model__link"
          style=?{color->Option.map(Braced.tone)}
          markerEnd={`url(#${hued(processId, color)})`}
          d={`M ${n(x0)} ${n(y0)} C ${n(x1)} ${n(y1)}, ${n(x2)} ${n(y2)}, ${n(s3x)} ${n(s3y)} L ${n(
              x3,
            )} ${n(y3)}`}
          dataProcess=""
        />,
      )
    | _ => None
    }
  )
  let tables = pick(op =>
    switch op {
    // A table with a colour, its own or its tenant's, takes that hue.
    | ModelOp.Table({x, y, width, height, name, tenant, color, kindX, valueX, columns, groups}) =>
      let left = x +. pad
      Some(
        <g className="model__table" style=?{color->Option.map(Braced.tone)}>
          <rect x={n(x)} y={n(y)} width={n(width)} height={n(height)} />
          // A group with a colour tints its rows, from its line to the next
          // group's or the table's foot, whose corners it keeps.
          {groups
          ->Array.mapWithIndex((g, index) =>
            switch g.color {
            | Some(hue) =>
              let top = g.from->Option.isSome ? g.y +. 4. : g.y
              let next = groups->Array.get(index + 1)
              let bottom = next->Option.mapOr(y +. height, next => next.y +. 4.)
              <rect
                className={next->Option.isSome ? "model__region" : "model__region model__region--foot"}
                style={Braced.tone(hue)}
                x={n(x)}
                y={n(top)}
                width={n(width)}
                height={n(bottom -. top)}
              />
            | None => Draw.null
            }
          )
          ->Draw.array}
          {groups->Array.some(g => g.color->Option.isSome)
            ? <rect className="model__outline" x={n(x)} y={n(y)} width={n(width)} height={n(height)} />
            : Draw.null}
          <text className="model__name" x={n(left)} y={n(y +. headHeight /. 2. +. 4.)}>
            {text(name)}
          </text>
          {switch tenant {
          | Some(t) =>
            <text
              className="model__tenant"
              x={n(x +. width -. padRight)}
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
          {groups
          ->Array.map(g =>
            <>
              {switch g.name {
              | Some(said) =>
                <text
                  className="model__group"
                  x={n(x +. width -. padRight)}
                  y={n(g.y +. groupHeight +. baseline)}
                  textAnchor="end"
                >
                  {text(said)}
                </text>
              | None => Draw.null
              }}
              {switch g.from {
              | Some(from) =>
                let at = g.y +. 4.
                <line className="model__split" x1={n(from)} y1={n(at)} x2={n(x +. width)} y2={n(at)} />
              | None => Draw.null
              }}
            </>
          )
          ->Draw.array}
          {columns
          ->Array.map(c =>
            <>
              <text className="model__column" style=?{c.nameColor->Option.map(Braced.tone)} x={n(left)} y={n(c.y)}>
                {text(c.name)}
              </text>
              {switch c.kind {
              | Some(k) =>
                <text className="model__type" style=?{c.kindColor->Option.map(Braced.tone)} x={n(kindX)} y={n(c.y)}>
                  {text(k)}
                </text>
              | None => Draw.null
              }}
              {switch c.value {
              | Some(v) =>
                <text className="model__value" style=?{c.valueColor->Option.map(Braced.tone)} x={n(valueX)} y={n(c.y)}>
                  {text(v)}
                </text>
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
    | ModelOp.Link({color, label: Some(({x, y, text: said}, anchor))})
    | ModelOp.Parent({color, label: Some(({x, y, text: said}, anchor))})
    | ModelOp.Process({color, label: Some(({x, y, text: said}, anchor))}) =>
      Some(
        <text
          className="model__label"
          style=?{color->Option.map(Braced.tone)}
          x={n(x)}
          y={n(y)}
          textAnchor=anchor
        >
          {text(said)}
        </text>,
      )
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
