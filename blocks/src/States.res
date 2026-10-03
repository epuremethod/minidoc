// The `states` block: steps and the moves between them, drawn. The body is a
// grid of cells, a blank line, then the moves. The grid makes the layout.
// Ported from SWISSID's scripts/states.mjs, itself from sylva.

open Node
open StatesOp

let fail = Html.fail
let width = Sequence.width
let capture = Sequence.capture

let boxHeight = 30.
let pad = 13.
let gapX = 46.
// A column of empty cells is a lane for the lines that cross it: it keeps a
// width of its own instead of closing up.
let lane = 46.
let gapY = 84.
let margin = 10.
// A line leaves and reaches a box at right angles to the side it touches.
// The control point goes that far along the side's normal, so the curve
// keeps its first direction before it turns.
let pull = 0.45
let pullLeast = 34.
let pullMost = 96.
// The distance between a label and the line it names.
let labelOff = 11.

type point = {x: float, y: float}
type side = Right | Left | Top | Bottom

let normal = side =>
  switch side {
  | Right => {x: 1., y: 0.}
  | Left => {x: -1., y: 0.}
  | Top => {x: 0., y: -1.}
  | Bottom => {x: 0., y: 1.}
  }

let defaultKind = "step"

type cell = {name: string, kind: string}
type move = {from: string, to: string, label: string, at: float, right: bool, kind: option<string>}

let cellLine = RegExp.fromString("^[\\p{L}\\p{N}_.\\-]+(?::[\\p{L}]+)?$", ~flags="u")
let moveLine = RegExp.fromString("^ *(\\S+) +-> +(\\S+)(?: +(.*))?$")
let placedLabel = RegExp.fromString(
  "^(.*?)\\s*\\{(?:([01](?:\\.\\d+)?))?\\s*(right)?\\s*([\\p{L}]+)?\\}$",
  ~flags="u",
)
let space = RegExp.fromString("\\s+")

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
        let cells = line->String.trim->String.splitByRegExp(space)->Array.map(c => c->Option.getOr(""))
        if !(cells->Array.every(c => c == "." || RegExp.test(cellLine, c))) {
          fail(`states: cannot read the grid at ${at}`)
        }
        rows->Array.push(
          cells->Array.map(c =>
            if c == "." {
              None
            } else {
              let (name, kind) = switch String.split(c, ":") {
              | [name, kind] => (name, kind)
              | _ => (c, defaultKind)
              }
              if keys->Dict.get(kind)->Option.isNone {
                fail(`states: no kind called ${kind}, ${at}`)
              }
              Some({name, kind})
            }
          ),
        )
      | None =>
        switch RegExp.exec(moveLine, line) {
        | None => fail(`states: cannot read the move at ${at}`)
        | Some(m) =>
          // A label sits in the middle of its line, unless the move says
          // where: `{0.2}` for a fifth of the way. `{0.2 right}` also puts it
          // on the right of the way. A kind in the braces marks the move:
          // `{fail}`, `{0.2 fail}`.
          let said = String.trim(capture(m, 2)->Option.getOr(""))
          let placed = RegExp.exec(placedLabel, said)
          let kind = placed->Option.flatMap(p => capture(p, 3))
          kind->Option.forEach(kind =>
            if keys->Dict.get(kind)->Option.isNone {
              fail(`states: no kind called ${kind}, ${at}`)
            }
          )
          moves->Array.push({
            from: capture(m, 0)->Option.getOr(""),
            to: capture(m, 1)->Option.getOr(""),
            label: placed->Option.flatMap(p => capture(p, 0))->Option.getOr(said),
            at: placed
            ->Option.flatMap(p => capture(p, 1))
            ->Option.flatMap(Float.fromString)
            ->Option.getOr(0.5),
            right: placed->Option.flatMap(p => capture(p, 2))->Option.isSome,
            kind,
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

type placed = {
  name: string,
  kind: string,
  row: int,
  column: int,
  x: float,
  y: float,
  w: float,
  middle: float,
  centre: float,
}

// A column is as wide as its widest box: a long name pushes one column and
// not the whole grid. A column with no box is a lane.
let place = (rows: array<array<option<cell>>>) => {
  let columns = rows->Array.reduce(0, (most, row) => Math.Int.max(most, Array.length(row)))
  let widths = Array.fromInitializer(~length=columns, column => {
    let names = rows->Array.filterMap(row => row->Array.get(column)->Option.flatMap(c => c))
    let names: array<cell> = names
    names == []
      ? lane
      : Math.ceil(Math.maxMany(names->Array.map(c => width(c.name, 13.) +. pad *. 2.)))
  })
  let lefts = []
  let x = ref(0.)
  widths->Array.forEach(w => {
    lefts->Array.push(x.contents)
    x := x.contents +. w +. gapX
  })
  let boxes = []
  rows->Array.forEachWithIndex((row, line) =>
    row->Array.forEachWithIndex((cell, column) =>
      cell->Option.forEach(cell => {
        let x = lefts->Array.getUnsafe(column)
        let y = Int.toFloat(line) *. (boxHeight +. gapY)
        let w = widths->Array.getUnsafe(column)
        boxes->Array.push({
          name: cell.name,
          kind: cell.kind,
          row: line,
          column,
          x,
          y,
          w,
          middle: y +. boxHeight /. 2.,
          centre: x +. w /. 2.,
        })
      })
    )
  )
  (boxes, boxes->Array.reduce(0., (most, b) => Math.max(most, b.x +. b.w)))
}

/** A point on a cubic: a label may sit anywhere along the line it names. */
let along = (t, p0, p1, p2, p3) => {
  let u = 1. -. t
  u *. u *. u *. p0 +. 3. *. u *. u *. t *. p1 +. 3. *. u *. t *. t *. p2 +. t *. t *. t *. p3
}

type line = {
  move: move,
  from: placed,
  to: placed,
  fromSide: side,
  toSide: side,
  mutable tail: option<point>,
  mutable head: option<point>,
}

// The sides a move leaves and reaches. Two boxes of one row are joined by a
// straight line, unless a third stands between them: then the line goes over
// the row. Two boxes of different rows are joined by a curve that leaves by
// the facing side.
let shape = (move: move, boxes: array<placed>): line => {
  let get = name => boxes->Array.findLast((b: placed) => b.name == name)->Option.getOrThrow
  let from = get(move.from)
  let to = get(move.to)
  let (fromSide, toSide) = if from.row == to.row {
    let low = Math.Int.min(from.column, to.column)
    let high = Math.Int.max(from.column, to.column)
    let blocked = boxes->Array.some(b => b.row == from.row && b.column > low && b.column < high)
    if blocked {
      (Top, Top)
    } else if to.column > from.column {
      (Right, Left)
    } else {
      (Left, Right)
    }
  } else if to.row > from.row {
    (Bottom, Top)
  } else {
    (Top, Bottom)
  }
  {move, from, to, fromSide, toSide, tail: None, head: None}
}

let sign = x => x > 0. ? 1. : x < 0. ? -1. : 0.
let orElse = (first, second) => first != 0. ? first : second

// Each line that touches a side of a box gets its own point there. Else they
// all reach the centre and pile up. They are ordered by where their other end
// is, so that they spread without crossing at the box.
let anchor = lines => {
  let sides: array<(placed, side, array<(line, placed)>)> = []
  let put = (box, side, line, far) =>
    switch sides->Array.find(((b, s, _)) => b.name == box.name && s == side) {
    | Some((_, _, ends)) => ends->Array.push((line, far))
    | None => sides->Array.push((box, side, [(line, far)]))
    }
  lines->Array.forEach(line => {
    put(line.from, line.fromSide, line, line.to)
    put(line.to, line.toSide, line, line.from)
  })
  sides->Array.forEach(((box, side, ends)) => {
    let across = side == Top || side == Bottom
    // Two far boxes of one column tie. The nearer line keeps the side that
    // faces them: the farther one goes round it instead of crossing it.
    let reach = far => Math.abs(far.middle -. box.middle) *. sign(orElse(far.centre -. box.centre, 1.))
    ends->Array.sort(((_, one), (_, other)) =>
      across
        ? orElse(one.centre -. other.centre, reach(other) -. reach(one))
        : one.middle -. other.middle
    )
    let run = across ? box.w : boxHeight
    let start = across ? box.x : box.y
    let count = Int.toFloat(Array.length(ends) + 1)
    ends->Array.forEachWithIndex(((line, _), index) => {
      let at = start +. run *. Int.toFloat(index + 1) /. count
      let point = across
        ? {x: at, y: side == Top ? box.y : box.y +. boxHeight}
        : {x: side == Left ? box.x : box.x +. box.w, y: at}
      if line.from.name == box.name && line.fromSide == side && line.tail->Option.isNone {
        line.tail = Some(point)
      } else {
        line.head = Some(point)
      }
    })
  })
  lines
}

type drawn = {move: move, points: array<float>, x: float, y: float, anchor: string, ridden: array<point>}

let draw = (line, paired) => {
  let tail = line.tail->Option.getOrThrow
  let head = line.head->Option.getOrThrow
  let out = normal(line.fromSide)
  let into = normal(line.toSide)
  let span = Math.hypot(head.x -. tail.x, head.y -. tail.y)
  let pull = Math.min(Math.max(span *. pull, pullLeast), pullMost)
  let one = {x: tail.x +. out.x *. pull, y: tail.y +. out.y *. pull}
  let other = {x: head.x +. into.x *. pull, y: head.y +. into.y *. pull}
  let at = t => {
    x: along(t, tail.x, one.x, other.x, head.x),
    y: along(t, tail.y, one.y, other.y, head.y),
  }

  // The label sits beside the line, on the side away from the middle of the
  // pair. Two lines between the same boxes spread apart at the box, and
  // reading outward also parts their labels. A move that says `right` puts
  // its label on the right of its way, paired or not.
  let where = line.move.at
  let middle = at(where)
  let ahead = at(Math.min(where +. 0.04, 1.))
  let behind = at(Math.max(where -. 0.04, 0.))
  let run = orElse(Math.hypot(ahead.x -. behind.x, ahead.y -. behind.y), 1.)
  let left = {x: (ahead.y -. behind.y) /. run, y: (behind.x -. ahead.x) /. run}
  let away = {
    x: middle.x -. (line.from.centre +. line.to.centre) /. 2.,
    y: middle.y -. (line.from.middle +. line.to.middle) /. 2.,
  }
  let outward = left.x *. away.x +. left.y *. away.y >= 0.
  let flipped = line.move.right || (paired && !outward)
  let side = flipped ? {x: -.left.x, y: -.left.y} : left
  let x = middle.x +. side.x *. labelOff
  let y = middle.y +. side.y *. labelOff +. (side.y < -0.5 ? -1. : side.y > 0.5 ? 9. : 4.)
  {
    move: line.move,
    points: [tail.x, tail.y, one.x, one.y, other.x, other.y, head.x, head.y],
    x,
    y,
    anchor: side.x > 0.5 ? "start" : side.x < -0.5 ? "end" : "middle",
    ridden: [0., 0.25, 0.5, 0.75, 1.]->Array.map(at),
  }
}

let pairKey = (one, other) => [one, other]->Array.toSorted(String.compare)->Array.join(" ")

/** The drawing of a state machine: its operations, placed. */
let read = (text, caption, kinds: dict<string>): drawing<StatesOp.t> => {
  let keys = Dict.fromArray([(defaultKind, "a step"), ...Dict.toArray(kinds)])
  let (rows, moves, legend) = readText(text, keys)
  let (boxes, right) = place(rows)
  let lines = anchor(moves->Array.map(move => shape(move, boxes)))
  // Two boxes joined both ways carry two labels, and those are the ones that
  // must read outward.
  let pairs = Dict.make()
  lines->Array.forEach(line => {
    let key = pairKey(line.from.name, line.to.name)
    pairs->Dict.set(key, pairs->Dict.get(key)->Option.getOr(0) + 1)
  })
  let drawn = lines->Array.map(line =>
    draw(line, pairs->Dict.get(pairKey(line.from.name, line.to.name))->Option.getOr(0) > 1)
  )

  let ridden = drawn->Array.flatMap(d => d.ridden->Array.map(p => p.y))
  let top = Math.minMany([
    ...boxes->Array.map(b => b.y),
    ...ridden,
    ...drawn->Array.map(d => d.y -. 12.),
  ])
  let bottom = Math.maxMany([
    ...boxes->Array.map(b => b.y +. boxHeight),
    ...ridden,
    ...drawn->Array.map(d => d.y +. 6.),
  ])
  // A label that reaches past the boxes is part of the drawing: the frame
  // holds it instead of cutting it.
  let reaches = drawn->Array.flatMap(d =>
    if d.move.label == "" {
      []
    } else {
      let run = width(d.move.label, 11.)
      let left = d.anchor == "start" ? d.x : d.anchor == "end" ? d.x -. run : d.x -. run /. 2.
      [left, left +. run]
    }
  )
  let left = Math.minMany([0., ...reaches])
  let w = Math.maxMany([right, ...reaches]) -. left

  let used = boxes->Array.map(b => b.kind)->Sequence.unique
  let marked = moves->Array.filterMap(m => m.kind)->Sequence.unique
  let key = (kind, move) => {kind, text: keys->Dict.get(kind)->Option.getOr(kind), move}
  {
    ops: [
      Frame({
        left: left -. margin,
        top: top -. margin,
        width: w +. margin *. 2.,
        height: bottom -. top +. margin *. 2.,
      }),
      ...boxes->Array.map(b => Box({kind: b.kind, x: b.x, y: b.y, width: b.w, height: boxHeight, name: b.name})),
      ...drawn->Array.map(d => Move({
        kind: d.move.kind,
        points: d.points,
        label: d.move.label == ""
          ? None
          : Some(({x: Math.round(d.x), y: Math.round(d.y), text: d.move.label}, d.anchor)),
      })),
    ],
    caption,
    keys: legend
      ? [...used->Array.map(kind => key(kind, false)), ...marked->Array.map(kind => key(kind, true))]
      : [],
  }
}

let n = Float.toString

// A kind of the project's reads its colour from `--tone-<kind>`.
let tone = kind => kind == defaultKind ? "" : ` style="--tone: var(--tone-${kind}, var(--blocks-ink))"`
let escape = Html.escape

// An arrowhead takes no colour from the line that uses it, so a marked move
// gets an arrowhead of its own kind.
let marker = kind =>
  `<marker id="states-tip${kind->Option.mapOr("", k => `-${k}`)}"${kind->Option.mapOr("", tone)} viewBox="0 0 14 10" refX="13" refY="5" markerWidth="14" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto"><path class="states__tip" d="M 0 0 L 14 5 L 0 10 L 3.8 5 z" /></marker>`

/** The SVG of a state machine, painted from its operations. */
let render = (drawing: drawing<StatesOp.t>) => {
  let pick = f => drawing.ops->Array.filterMap(f)->Array.join("")
  let frame = drawing.ops->Array.findMap(op =>
    switch op {
    | Frame(f) => Some(f)
    | _ => None
    }
  )->Option.getOrThrow
  let paths = pick(op =>
    switch op {
    | Move({kind, points: [x0, y0, x1, y1, x2, y2, x3, y3], label}) =>
      let text = label->Option.mapOr("", ((l, _)) => l.text)
      let modifier = kind->Option.mapOr("", k => ` states__move--${k}`)
      let colour = kind->Option.mapOr("", tone)
      let tip = kind->Option.mapOr("states-tip", k => `states-tip-${k}`)
      Some(
        `<path class="states__move${modifier}"${colour} marker-end="url(#${tip})" d="M ${n(x0)} ${n(y0)} C ${n(x1)} ${n(y1)}, ${n(x2)} ${n(y2)}, ${n(x3)} ${n(y3)}" data-move="${escape(text)}" />`,
      )
    | _ => None
    }
  )
  let shapes = pick(op =>
    switch op {
    | Box({kind, x, y, width, height, name}) =>
      Some(
        `<g class="states__box states__box--${kind}"${tone(kind)}><rect x="${n(x)}" y="${n(y)}" width="${n(width)}" height="${n(height)}" rx="7" /><text x="${n(x +. width /. 2.)}" y="${n(y +. height /. 2. +. 4.)}" text-anchor="middle">${escape(name)}</text></g>`,
      )
    | _ => None
    }
  )
  let notes = pick(op =>
    switch op {
    | Move({kind, label: Some(({x, y, text}, anchor))}) =>
      Some(`<text class="states__label"${kind->Option.mapOr("", tone)} text-anchor="${anchor}" x="${n(x)}" y="${n(y)}">${escape(text)}</text>`)
    | _ => None
    }
  )
  let label = drawing.caption->Option.getOr("A state machine")
  let title = drawing.caption->Option.mapOr("", c => `<span class="states__title">${escape(c)}</span>`)
  let keyed =
    drawing.keys == []
      ? ""
      : `<span class="states__keys">${drawing.keys
          ->Array.map(({kind, text, move}) =>
            `<span class="states__key states__key--${kind}${move ? " states__key--move" : ""}"${tone(kind)}>${escape(text)}</span>`
          )
          ->Array.join("")}</span>`
  let under = title ++ keyed == "" ? "" : `<figcaption class="states__caption">${title}${keyed}</figcaption>`
  let kinds = drawing.ops->Array.filterMap(op =>
    switch op {
    | Move({kind}) => kind
    | _ => None
    }
  )->Sequence.unique
  let tips = `<defs>${[None, ...kinds->Array.map(k => Some(k))]->Array.map(marker)->Array.join("")}</defs>`
  `<figure class="states"><svg class="states__svg" viewBox="${n(frame.left)} ${n(frame.top)} ${n(frame.width)} ${n(frame.height)}" width="${n(frame.width)}" height="${n(frame.height)}" role="img" aria-label="${escape(label)}">${tips}${paths}${shapes}${notes}</svg>${under}</figure>`
}
