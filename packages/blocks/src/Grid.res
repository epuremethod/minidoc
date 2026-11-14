// The grid a drawing is placed on: boxes in rows and columns, and the curved
// lines between them. `states` and `model` share it. A box brings its own
// size, and a column is as wide as its widest box.

open Node

let width = Sequence.width
let capture = Sequence.capture

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

/** A box to place: its name, its least size, and what the drawing keeps with it. */
type box<'a> = {name: string, w: float, h: float, data: 'a}

type placed<'a> = {
  name: string,
  data: 'a,
  row: int,
  column: int,
  x: float,
  y: float,
  w: float,
  h: float,
  // The height every box of the row shares, from the top: a line leaves or
  // reaches a left or right side within it.
  band: float,
  middle: float,
  centre: float,
}

/** A line to draw between two boxes, and where its label sits. */
type way = {from: string, to: string, label: string, at: float, right: bool}

/** The boxes placed on the grid, and the right edge of the widest row.
    `across` is the gap between two columns. */
let place = (~across=gapX, rows: array<array<option<box<'a>>>>) => {
  let columns = rows->Array.reduce(0, (most, row) => Math.Int.max(most, Array.length(row)))
  let all = rows->Array.flat->Array.filterMap(b => b)
  let widths = Array.fromInitializer(~length=columns, column => {
    let held = rows->Array.filterMap(row => row->Array.get(column)->Option.flatMap(b => b))
    held == [] ? lane : Math.ceil(Math.maxMany(held->Array.map(b => b.w)))
  })
  // A row is as tall as its tallest box. A row of empty cells keeps the
  // height of the smallest box, so the rows around it stay apart.
  let least = all == [] ? 0. : Math.minMany(all->Array.map(b => b.h))
  let heights = rows->Array.map(row => {
    let held = row->Array.filterMap(b => b)
    held == [] ? least : Math.maxMany(held->Array.map(b => b.h))
  })
  let lefts = []
  let x = ref(0.)
  widths->Array.forEach(w => {
    lefts->Array.push(x.contents)
    x := x.contents +. w +. across
  })
  let tops = []
  let y = ref(0.)
  heights->Array.forEach(h => {
    tops->Array.push(y.contents)
    y := y.contents +. h +. gapY
  })
  let bands = rows->Array.map(row => {
    let held = row->Array.filterMap(b => b)
    held == [] ? least : Math.minMany(held->Array.map(b => b.h))
  })
  let boxes = []
  rows->Array.forEachWithIndex((row, line) =>
    row->Array.forEachWithIndex((cell, column) =>
      cell->Option.forEach(cell => {
        let x = lefts->Array.getUnsafe(column)
        let y = tops->Array.getUnsafe(line)
        let w = widths->Array.getUnsafe(column)
        boxes->Array.push({
          name: cell.name,
          data: cell.data,
          row: line,
          column,
          x,
          y,
          w,
          h: cell.h,
          band: bands->Array.getUnsafe(line),
          middle: y +. cell.h /. 2.,
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

// The values of one coordinate of a cubic at its ends and where it turns:
// its least and its most are among them.
let turns = (p0, p1, p2, p3) => {
  let (p, q, r) = (p1 -. p0, p2 -. p1, p3 -. p2)
  let (a, b, c) = (p -. 2. *. q +. r, 2. *. (q -. p), p)
  let roots = if a == 0. {
    b == 0. ? [] : [-.c /. b]
  } else {
    let d = b *. b -. 4. *. a *. c
    d < 0. ? [] : [(-.b +. Math.sqrt(d)) /. (2. *. a), (-.b -. Math.sqrt(d)) /. (2. *. a)]
  }
  [0., 1., ...roots->Array.filter(t => t > 0. && t < 1.)]->Array.map(t => along(t, p0, p1, p2, p3))
}

type line<'a> = {
  way: way,
  from: placed<'a>,
  to: placed<'a>,
  fromSide: side,
  toSide: side,
  /** The drawing reads left to right, and a line forks off a right side. */
  forks: bool,
  mutable tail: option<point>,
  mutable head: option<point>,
}

// The sides a line leaves and reaches. Two boxes of one row are joined by a
// straight line, unless a third stands between them: then the line goes over
// the row. Two boxes of different rows are joined by a curve that leaves by
// the facing side. A line from a box to itself leaves the right side and
// comes back into the top. In a drawing that `forks`, a line to a later
// column on another row leaves the right side and reaches the left one, as
// the drawing reads.
let shape = (way: way, boxes: array<placed<'a>>, ~forks): line<'a> => {
  let get = name => boxes->Array.findLast((b: placed<'a>) => b.name == name)->Option.getOrThrow
  let from = get(way.from)
  let to = get(way.to)
  let (fromSide, toSide) = if from.name == to.name {
    (Right, Top)
  } else if from.row == to.row {
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
  } else if forks && to.column > from.column {
    (Right, Left)
  } else if to.row > from.row {
    (Bottom, Top)
  } else {
    (Top, Bottom)
  }
  {way, from, to, fromSide, toSide, forks, tail: None, head: None}
}

let sign = x => x > 0. ? 1. : x < 0. ? -1. : 0.
let orElse = (first, second) => first != 0. ? first : second

// Each line that touches a side of a box gets its own point there. Else they
// all reach the centre and pile up. They are ordered by where their other end
// is, so that they spread without crossing at the box. A left or right side
// spreads them over the row's band, not the box's height: two boxes of one
// row, the one taller than the other, are joined by a straight line.
// A line from a box to itself is a loop at the box's top-right corner. Its
// two ends stand that far from the corner, so the curve, pulled outward at
// each end, stays outside the box. A second loop on the same box stands
// twice as far, and goes round the first. Loops take no part in the spread.
// A loop pulls further than a line between two boxes, so that it clears the
// marks at its ends and its label clears the lines beside it.
let loopInset = 20.
let loopPull = 64.

let anchor = (lines: array<line<'a>>) => {
  let sides: array<(placed<'a>, side, array<(line<'a>, placed<'a>)>)> = []
  let put = (box: placed<'a>, side, line, far) =>
    switch sides->Array.find(((b, s, _)) => b.name == box.name && s == side) {
    | Some((_, _, ends)) => ends->Array.push((line, far))
    | None => sides->Array.push((box, side, [(line, far)]))
    }
  let loops = Dict.make()
  lines->Array.forEach(line =>
    if line.from.name == line.to.name {
      let box = line.from
      let index = loops->Dict.get(box.name)->Option.getOr(0)
      loops->Dict.set(box.name, index + 1)
      let inset = loopInset *. Int.toFloat(index + 1)
      line.tail = Some({x: box.x +. box.w, y: box.y +. Math.min(inset, box.band /. 2.)})
      line.head = Some({x: box.x +. box.w -. Math.min(inset, box.w /. 2.), y: box.y})
    } else {
      put(line.from, line.fromSide, line, line.to)
      put(line.to, line.toSide, line, line.from)
    }
  )
  sides->Array.forEach(((box, side, ends)) => {
    let across = side == Top || side == Bottom
    // Two far boxes of one column tie. The nearer line keeps the side that
    // faces them: the farther one goes round it instead of crossing it.
    let reach = (far: placed<'a>) =>
      Math.abs(far.middle -. box.middle) *. sign(orElse(far.centre -. box.centre, 1.))
    ends->Array.sort(((_, one), (_, other)) =>
      across
        ? orElse(one.centre -. other.centre, reach(other) -. reach(one))
        : one.middle -. other.middle
    )
    // In a drawing that forks, the lines that leave a right side count as
    // one end there: they start from one point, and part after it.
    let leaves = ((line, _)) =>
      line.forks && side == Right && line.from.name == box.name && line.fromSide == Right
    let fork = ref(None)
    let slots = ref(0)
    let indices = ends->Array.map(end => {
      let take = () => {
        let index = slots.contents
        slots := index + 1
        index
      }
      switch (leaves(end), fork.contents) {
      | (true, Some(index)) => index
      | (true, None) =>
        let index = take()
        fork := Some(index)
        index
      | (false, _) => take()
      }
    })
    let run = across ? box.w : box.band
    let start = across ? box.x : box.y
    let count = Int.toFloat(slots.contents + 1)
    ends->Array.forEachWithIndex(((line, _), index) => {
      let index = indices->Array.getUnsafe(index)
      let at = start +. run *. Int.toFloat(index + 1) /. count
      let point = across
        ? {x: at, y: side == Top ? box.y : box.y +. box.h}
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

/** The point `length` from (x, y) toward (towardX, towardY): where a line's straight end begins. */
let stub = (x, y, towardX, towardY, length) => {
  let run = Math.hypot(towardX -. x, towardY -. y)
  run == 0.
    ? (x, y)
    : (x +. (towardX -. x) /. run *. length, y +. (towardY -. y) /. run *. length)
}

/** A line, drawn: its cubic, and its label's point and anchor. */
type drawn = {way: way, points: array<float>, x: float, y: float, anchor: string, ridden: array<point>}

let draw = (line: line<'a>, paired) => {
  let tail = line.tail->Option.getOrThrow
  let head = line.head->Option.getOrThrow
  let out = normal(line.fromSide)
  let into = normal(line.toSide)
  let span = Math.hypot(head.x -. tail.x, head.y -. tail.y)
  let loop = line.from.name == line.to.name
  // A fork to another row pulls by half the distance across: both handles
  // meet at the middle of the gap, so the curve turns over its whole length
  // and never bends back.
  let pull = if loop {
    loopPull
  } else if (
    line.forks && line.fromSide == Right && line.toSide == Left && line.from.row != line.to.row
  ) {
    Math.abs(head.x -. tail.x) /. 2.
  } else {
    Math.min(Math.max(span *. pull, pullLeast), pullMost)
  }
  let one = {x: tail.x +. out.x *. pull, y: tail.y +. out.y *. pull}
  let other = {x: head.x +. into.x *. pull, y: head.y +. into.y *. pull}
  let at = t => {
    x: along(t, tail.x, one.x, other.x, head.x),
    y: along(t, tail.y, one.y, other.y, head.y),
  }

  // The label sits beside the line, on the side away from the middle of the
  // pair. Two lines between the same boxes spread apart at the box, and
  // reading outward also parts their labels. A line that says `right` puts
  // its label on the right of its way, paired or not.
  let where = line.way.at
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
  let flipped = line.way.right || (paired && !outward)
  let side = flipped ? {x: -.left.x, y: -.left.y} : left
  // A loop's label stands right of the loop, halfway between its top and
  // its tail. Its middle would be near its top, over the lines above the
  // box. A loop has one outer side, so `{0.2}` and `right` do not move it.
  let (x, y, anchor) = if loop {
    let most = Math.maxMany(turns(tail.x, one.x, other.x, head.x))
    let top = Math.minMany(turns(tail.y, one.y, other.y, head.y))
    (most +. labelOff, (top +. tail.y) /. 2. +. 4., "start")
  } else {
    (
      middle.x +. side.x *. labelOff,
      middle.y +. side.y *. labelOff +. (side.y < -0.5 ? -7. : side.y > 0.5 ? 9. : 4.),
      side.x > 0.5 ? "start" : side.x < -0.5 ? "end" : "middle",
    )
  }
  {
    way: line.way,
    points: [tail.x, tail.y, one.x, one.y, other.x, other.y, head.x, head.y],
    x,
    y,
    anchor,
    ridden: [0., 0.25, 0.5, 0.75, 1.]->Array.map(at),
  }
}

let pairKey = (one, other) => [one, other]->Array.toSorted(String.compare)->Array.join(" ")

/** The lines between placed boxes, drawn in the order of `ways`. */
let route = (~forks=false, ways: array<way>, boxes: array<placed<'a>>) => {
  let lines = anchor(ways->Array.map(way => shape(way, boxes, ~forks)))
  // Two boxes joined both ways carry two labels, and those are the ones that
  // must read outward.
  let pairs = Dict.make()
  lines->Array.forEach(line => {
    let key = pairKey(line.from.name, line.to.name)
    pairs->Dict.set(key, pairs->Dict.get(key)->Option.getOr(0) + 1)
  })
  lines->Array.map(line =>
    draw(line, pairs->Dict.get(pairKey(line.from.name, line.to.name))->Option.getOr(0) > 1)
  )
}

/** The frame that holds the boxes, the lines and their labels. */
let frame = (boxes: array<placed<'a>>, drawn: array<drawn>, right) => {
  let ridden = drawn->Array.flatMap(d => d.ridden->Array.map(p => p.y))
  let top = Math.minMany([
    ...boxes->Array.map(b => b.y),
    ...ridden,
    ...drawn->Array.map(d => d.y -. 12.),
  ])
  let bottom = Math.maxMany([
    ...boxes->Array.map(b => b.y +. b.h),
    ...ridden,
    ...drawn->Array.map(d => d.y +. 6.),
  ])
  // A label that reaches past the boxes is part of the drawing: the frame
  // holds it instead of cutting it.
  let reaches = drawn->Array.flatMap(d =>
    if d.way.label == "" {
      []
    } else {
      let run = width(d.way.label, 11.)
      let left = d.anchor == "start" ? d.x : d.anchor == "end" ? d.x -. run : d.x -. run /. 2.
      [left, left +. run]
    }
  )
  let left = Math.minMany([0., ...reaches])
  let w = Math.maxMany([right, ...reaches]) -. left
  {
    left: left -. margin,
    top: top -. margin,
    width: w +. margin *. 2.,
    height: bottom -. top +. margin *. 2.,
  }
}

/** A drawn line's label, rounded, with its anchor; none when it has no text. */
let placedText = (d: drawn) =>
  d.way.label == ""
    ? None
    : Some(({x: Math.round(d.x), y: Math.round(d.y), text: d.way.label}, d.anchor))
