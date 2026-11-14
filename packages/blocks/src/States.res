// The `states` block: steps and the moves between them, drawn. The body is a
// grid of cells, a blank line, then the moves. The grid makes the layout.
// Ported from SWISSID's scripts/states.mjs, itself from sylva.

@@jsxConfig({version: 4, module_: "Draw"})

open Node
open StatesOp

let fail = Html.fail
let width = Sequence.width
let capture = Sequence.capture

let boxHeight = 30.
let pad = 13.

let defaultKind = "step"

type cell = {name: string, kind: string}
type move = {
  from: string,
  to: string,
  label: string,
  at: float,
  right: bool,
  kind: option<string>,
  color: option<string>,
  both: bool,
}

let cellLine = RegExp.fromString("^[\\p{L}\\p{N}_.\\-]+(?::[\\p{L}]+)?$", ~flags="u")
// A name in braces holds spaces and its attributes: `{en attente, active}`.
let name = "(\\{[^}]*\\}|\\S+)"
// `a -> b` goes one way, `a <-> b` goes both: one line, a tip at each end.
let moveLine = RegExp.fromString(`^ *${name} +(<?->) +${name}(?: +(.*))?$`)

let readText = (text, keys: dict<string>) => {
  let rows: array<array<option<cell>>> = []
  let moves = []
  let legend = ref(false)
  let marks = Dict.make()
  let past = ref(false)
  // A name as written, with what its attributes mark: `active`, a colour,
  // or a kind of the project's.
  let named = (word, at) => {
    let {text, attributes}: Braced.t = Braced.read(word, ~block="states", ~at)
    let found = Braced.marks(text, attributes, ~block="states", ~at, ~active=true, ~kinds=keys)
    marks->Braced.merge(text, found, ~block="states", ~at)
    (text, found)
  }
  text
  ->String.split("\n")
  ->Array.forEachWithIndex((raw, index) => {
    let line = String.trimEnd(raw)
    let at = `line ${Int.toString(index + 1)}`
    if String.trim(line) == "" {
      if Array.length(rows) > 0 {
        past := true
      }
    } else if !String.startsWith(String.trim(line), "#") {
      switch RegExp.exec(Sequence.directiveLine, String.trim(line)) {
      | Some(d) if past.contents || capture(d, 0) == Some("legend") =>
        let name = capture(d, 0)->Option.getOr("")
        if name != "legend" {
          fail(`states: no directive {${name}}, ${at}`)
        }
        legend := true
      | _ if !past.contents =>
        rows->Array.push(
          Braced.words(line, ~block="states", ~at)->Array.map(c =>
            if c == "." {
              None
            } else if String.startsWith(c, "{") {
              let (name, found) = named(c, at)
              Some({name, kind: found.kind->Option.getOr(defaultKind)})
            } else if RegExp.test(cellLine, c) {
              switch String.split(c, ":") {
              | [name, kind] =>
                if keys->Dict.get(kind)->Option.isNone {
                  fail(`states: no kind called ${kind}, ${at}`)
                }
                Some({name, kind})
              | _ => Some({name: c, kind: defaultKind})
              }
            } else {
              fail(`states: cannot read the grid at ${at}`)
            }
          ),
        )
      | _ =>
        switch RegExp.exec(moveLine, line) {
        | None => fail(`states: cannot read the move at ${at}`)
        | Some(m) =>
          let (from, _) = named(capture(m, 0)->Option.getOr(""), at)
          let (to, _) = named(capture(m, 2)->Option.getOr(""), at)
          let (label, where, right, kind, color) = Braced.label(
            capture(m, 3)->Option.getOr(""),
            ~block="states",
            ~at,
            ~kinds=keys,
          )
          moves->Array.push({
            from,
            to,
            label,
            at: where,
            right,
            kind,
            color,
            both: capture(m, 1) == Some("<->"),
          })
        }
      }
    }
  })
  if Array.length(rows) == 0 {
    fail("states: the grid is empty")
  }
  // A move names two boxes, and only the grid declares them.
  let placed = rows->Array.flat->Array.filterMap(c => c)->Array.map(c => c.name)
  moves->Array.flatMap(move => [move.from, move.to])->Array.forEach(name =>
    if !(placed->Array.includes(name)) {
      fail(`states: no box called ${name}`)
    }
  )
  // A kind given in braces on any mention marks the box.
  let rows = rows->Array.map(row =>
    row->Array.map(c =>
      c->Option.map(c => {
        ...c,
        kind: marks->Dict.get(c.name)->Option.flatMap(m => m.kind)->Option.getOr(c.kind),
      })
    )
  )
  (rows, moves, legend.contents, marks)
}

/** The drawing of a state machine: its operations, placed. */
let read = (text, caption, kinds: dict<string>): drawing<StatesOp.t> => {
  let keys = Dict.fromArray([(defaultKind, "a step"), ...Dict.toArray(kinds)])
  let (rows, moves, legend, marks) = readText(text, keys)
  let markOf = name => marks->Dict.get(name)->Option.getOr(Braced.none)
  // A fork needs room for an S: a grid that holds one takes a model's gap
  // between columns, so the curve leaves flat and arrives flat.
  let cellOf = name =>
    rows->Array.findIndexOpt(row => row->Array.some(c => c->Option.mapOr(false, c => c.name == name)))
    ->Option.map(line => (
      line,
      rows->Array.getUnsafe(line)->Array.findIndex(c => c->Option.mapOr(false, c => c.name == name)),
    ))
  let forks = moves->Array.some(m =>
    switch (cellOf(m.from), cellOf(m.to)) {
    | (Some((fromRow, fromColumn)), Some((toRow, toColumn))) => fromRow != toRow && toColumn > fromColumn
    | _ => false
    }
  )
  let (boxes, right) = Grid.place(
    ~across=forks ? Model.across : Grid.gapX,
    rows->Array.map(row =>
      row->Array.map(c =>
        c->Option.map((c: cell): Grid.box<string> => {
          name: c.name,
          w: width(c.name, 13.) +. pad *. 2.,
          h: boxHeight,
          data: c.kind,
        })
      )
    ),
  )
  let drawn = Grid.route(
    ~forks=true,
    moves->Array.map((m): Grid.way => {from: m.from, to: m.to, label: m.label, at: m.at, right: m.right}),
    boxes,
  )
  let used = boxes->Array.map(b => b.data)->Sequence.unique
  let marked = moves->Array.filterMap(m => m.kind)->Sequence.unique
  let key = (kind, move) => {kind, text: keys->Dict.get(kind)->Option.getOr(kind), move}
  {
    ops: [
      Frame(Grid.frame(boxes, drawn, right)),
      ...boxes->Array.map(b => Box({
        kind: b.data,
        x: b.x,
        y: b.y,
        width: b.w,
        height: b.h,
        name: b.name,
        active: markOf(b.name).active,
        color: markOf(b.name).color,
      })),
      ...drawn->Array.mapWithIndex((d, index) => {
        let move = moves->Array.getUnsafe(index)
        Move({
          kind: move.kind,
          color: move.color,
          both: move.both,
          points: d.points,
          label: Grid.placedText(d),
        })
      }),
    ],
    caption,
    keys: legend
      ? [...used->Array.map(kind => key(kind, false)), ...marked->Array.map(kind => key(kind, true))]
      : [],
  }
}

let n = Float.toString

// A kind of the project's reads its colour from `--tone-<kind>`.
let tone = kind =>
  kind == defaultKind ? None : Some(`--tone: var(--tone-${kind}, var(--blocks-ink))`)
let text = Draw.string

// The length of a move's tip, along its line.
let tipReach = 14.

// What marks a move: its colour, which comes before its kind, as on a box.
// A colour is written `hue-<hue>`.
let mark = (kind, color) => color->Option.map(hue => `hue-${hue}`)->Option.orElse(kind)
let markTone = mark =>
  String.startsWith(mark, "hue-") ? Some(Braced.tone(String.slice(mark, ~start=4))) : tone(mark)

// An arrowhead takes no colour from the line that uses it, so a marked move
// gets an arrowhead of its own mark. At the start of a two-way move, the same
// tip turns round.
let marker = mark =>
  <marker
    id={`states-tip${mark->Option.mapOr("", m => `-${m}`)}`}
    style=?{mark->Option.flatMap(markTone)}
    viewBox="0 0 14 10"
    refX="13"
    refY="5"
    markerWidth="14"
    markerHeight="10"
    markerUnits="userSpaceOnUse"
    orient="auto-start-reverse"
  >
    <path className="states__tip" d="M 0 0 L 14 5 L 0 10 L 3.8 5 z" />
  </marker>

/** The SVG of a state machine, painted from its operations. */
let draw = (drawing: drawing<StatesOp.t>) => {
  let pick = f => drawing.ops->Array.filterMap(f)->Draw.array
  let frame =
    drawing.ops
    ->Array.findMap(op =>
      switch op {
      | Frame(f) => Some(f)
      | _ => None
      }
    )
    ->Option.getOrThrow
  let paths = pick(op =>
    switch op {
    // A move reaches its tip in a straight piece, as a model's link does:
    // else the line still curves under the tip, and the tip looks askew.
    | Move({kind, color, both, points: [x0, y0, x1, y1, x2, y2, x3, y3], label}) =>
      let marked = mark(kind, color)
      let tip = `url(#${marked->Option.mapOr("states-tip", m => `states-tip-${m}`)})`
      let (s3x, s3y) = Grid.stub(x3, y3, x2, y2, tipReach *. Model.straight)
      let start = if both {
        let (s0x, s0y) = Grid.stub(x0, y0, x1, y1, tipReach *. Model.straight)
        `M ${n(x0)} ${n(y0)} L ${n(s0x)} ${n(s0y)}`
      } else {
        `M ${n(x0)} ${n(y0)}`
      }
      Some(
        <path
          className={`states__move${kind->Option.mapOr("", k => ` states__move--${k}`)}`}
          style=?{marked->Option.flatMap(markTone)}
          markerStart=?{both ? Some(tip) : None}
          markerEnd=tip
          d={`${start} C ${n(x1)} ${n(y1)}, ${n(x2)} ${n(y2)}, ${n(s3x)} ${n(s3y)} L ${n(x3)} ${n(y3)}`}
          dataMove={label->Option.mapOr("", ((l, _)) => l.text)}
        />,
      )
    | _ => None
    }
  )
  let shapes = pick(op =>
    switch op {
    // An active step takes the tone of a plan's current stage.
    // A colour of the palette comes before the colour of its kind.
    | Box({kind, x, y, width, height, name, active, color}) =>
      Some(
        <g
          className={`states__box states__box--${kind}${active ? " states__box--active" : ""}`}
          style=?{active
            ? Some("--tone: var(--tone-doing)")
            : color->Option.map(Braced.tone)->Option.orElse(tone(kind))}
        >
          <rect x={n(x)} y={n(y)} width={n(width)} height={n(height)} rx="7" />
          <text x={n(x +. width /. 2.)} y={n(y +. height /. 2. +. 4.)} textAnchor="middle">
            {text(name)}
          </text>
        </g>,
      )
    | _ => None
    }
  )
  let notes = pick(op =>
    switch op {
    | Move({kind, color, label: Some(({x, y, text: said}, anchor))}) =>
      Some(
        <text
          className="states__label"
          style=?{mark(kind, color)->Option.flatMap(markTone)}
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
  let title = drawing.caption->Option.map(c => <span className="states__title"> {text(c)} </span>)
  let keyed =
    drawing.keys == []
      ? None
      : Some(
          <span className="states__keys">
            {drawing.keys
            ->Array.map(({kind, text: said, move}) =>
              <span
                className={`states__key states__key--${kind}${move ? " states__key--move" : ""}`}
                style=?{tone(kind)}
              >
                {text(said)}
              </span>
            )
            ->Draw.array}
          </span>,
        )
  let under = [title, keyed]->Array.keepSome
  let marks =
    drawing.ops
    ->Array.filterMap(op =>
      switch op {
      | Move({kind, color}) => mark(kind, color)
      | _ => None
      }
    )
    ->Sequence.unique
  <figure className="states">
    <svg
      className="states__svg"
      viewBox={`${n(frame.left)} ${n(frame.top)} ${n(frame.width)} ${n(frame.height)}`}
      width={n(frame.width)}
      height={n(frame.height)}
      role="img"
      ariaLabel={drawing.caption->Option.getOr("A state machine")}
    >
      <defs> {[None, ...marks->Array.map(m => Some(m))]->Array.map(marker)->Draw.array} </defs>
      paths
      shapes
      notes
    </svg>
    {under == []
      ? Draw.null
      : <figcaption className="states__caption"> {Draw.array(under)} </figcaption>}
  </figure>
}
