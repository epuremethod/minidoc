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
  both: bool,
}

let cellLine = RegExp.fromString("^[\\p{L}\\p{N}_.\\-]+(?::[\\p{L}]+)?$", ~flags="u")
// `a -> b` goes one way, `a <-> b` goes both: one line, a tip at each end.
let moveLine = RegExp.fromString("^ *(\\S+) +(<?->) +(\\S+)(?: +(.*))?$")

let readText = (text, keys: dict<string>) => {
  let rows: array<array<option<cell>>> = []
  let moves = []
  let legend = ref(false)
  let past = ref(false)
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
      | Some(d) =>
        let name = capture(d, 0)->Option.getOr("")
        if name != "legend" {
          fail(`states: no directive {${name}}, ${at}`)
        }
        legend := true
      | None if !past.contents =>
        let cells = Grid.cells(line)
        if !(cells->Array.every(c => c->Option.mapOr(true, c => RegExp.test(cellLine, c)))) {
          fail(`states: cannot read the grid at ${at}`)
        }
        rows->Array.push(
          cells->Array.map(c =>
            c->Option.map(c => {
              let (name, kind) = switch String.split(c, ":") {
              | [name, kind] => (name, kind)
              | _ => (c, defaultKind)
              }
              if keys->Dict.get(kind)->Option.isNone {
                fail(`states: no kind called ${kind}, ${at}`)
              }
              {name, kind}
            })
          ),
        )
      | None =>
        switch RegExp.exec(moveLine, line) {
        | None => fail(`states: cannot read the move at ${at}`)
        | Some(m) =>
          // A kind in the braces marks the move: `{fail}`, `{0.2 fail}`.
          let (label, where, right, kind) = Grid.label(capture(m, 3)->Option.getOr(""))
          kind->Option.forEach(kind =>
            if keys->Dict.get(kind)->Option.isNone {
              fail(`states: no kind called ${kind}, ${at}`)
            }
          )
          moves->Array.push({
            from: capture(m, 0)->Option.getOr(""),
            to: capture(m, 2)->Option.getOr(""),
            label,
            at: where,
            right,
            kind,
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
  moves->Array.forEach(move =>
    [move.from, move.to]->Array.forEach(end =>
      if !(placed->Array.includes(end)) {
        fail(`states: no box called ${end}`)
      }
    )
  )
  (rows, moves, legend.contents)
}

/** The drawing of a state machine: its operations, placed. */
let read = (text, caption, kinds: dict<string>): drawing<StatesOp.t> => {
  let keys = Dict.fromArray([(defaultKind, "a step"), ...Dict.toArray(kinds)])
  let (rows, moves, legend) = readText(text, keys)
  let (boxes, right) = Grid.place(
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
    moves->Array.map((m): Grid.way => {from: m.from, to: m.to, label: m.label, at: m.at, right: m.right}),
    boxes,
  )
  let used = boxes->Array.map(b => b.data)->Sequence.unique
  let marked = moves->Array.filterMap(m => m.kind)->Sequence.unique
  let key = (kind, move) => {kind, text: keys->Dict.get(kind)->Option.getOr(kind), move}
  {
    ops: [
      Frame(Grid.frame(boxes, drawn, right)),
      ...boxes->Array.map(b => Box({kind: b.data, x: b.x, y: b.y, width: b.w, height: b.h, name: b.name})),
      ...drawn->Array.mapWithIndex((d, index) => {
        let move = moves->Array.getUnsafe(index)
        Move({kind: move.kind, both: move.both, points: d.points, label: Grid.placedText(d)})
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

// An arrowhead takes no colour from the line that uses it, so a marked move
// gets an arrowhead of its own kind. At the start of a two-way move, the same
// tip turns round.
let marker = kind =>
  <marker
    id={`states-tip${kind->Option.mapOr("", k => `-${k}`)}`}
    style=?{kind->Option.flatMap(tone)}
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
    | Move({kind, both, points: [x0, y0, x1, y1, x2, y2, x3, y3], label}) =>
      let tip = `url(#${kind->Option.mapOr("states-tip", k => `states-tip-${k}`)})`
      Some(
        <path
          className={`states__move${kind->Option.mapOr("", k => ` states__move--${k}`)}`}
          style=?{kind->Option.flatMap(tone)}
          markerStart=?{both ? Some(tip) : None}
          markerEnd=tip
          d={`M ${n(x0)} ${n(y0)} C ${n(x1)} ${n(y1)}, ${n(x2)} ${n(y2)}, ${n(x3)} ${n(y3)}`}
          dataMove={label->Option.mapOr("", ((l, _)) => l.text)}
        />,
      )
    | _ => None
    }
  )
  let shapes = pick(op =>
    switch op {
    | Box({kind, x, y, width, height, name}) =>
      Some(
        <g className={`states__box states__box--${kind}`} style=?{tone(kind)}>
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
    | Move({kind, label: Some(({x, y, text: said}, anchor))}) =>
      Some(
        <text
          className="states__label"
          style=?{kind->Option.flatMap(tone)}
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
  let kinds =
    drawing.ops
    ->Array.filterMap(op =>
      switch op {
      | Move({kind}) => kind
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
      <defs> {[None, ...kinds->Array.map(k => Some(k))]->Array.map(marker)->Draw.array} </defs>
      paths
      shapes
      notes
    </svg>
    {under == []
      ? Draw.null
      : <figcaption className="states__caption"> {Draw.array(under)} </figcaption>}
  </figure>
}
