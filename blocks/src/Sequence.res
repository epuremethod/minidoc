// The `sequence` block: what passes between the parties of a process, in
// order. The first line names the parties, left to right, and each gets a
// lane. Each line after it is a step down the page: a message from one party
// to another, a refusal, or a party's state. The order of the lines makes the
// layout. Ported from SWISSID's scripts/sequence.mjs, itself from sylva.

open Node
open SequenceOp

let fail = Html.fail

let headHeight = 26.
let laneLeast = 84.
let pad = 12.
let stepHeight = 32.
let gapLeast = 64.
let top = 24.
let margin = 10.
let stateHeight = 20.
// The distance between a label and the line it names.
let labelUp = 5.

let chars: string => array<string> = %raw(`(text) => [...text]`)
let narrow = chars("iljtfrI'.,:;!|()[]")
let wide = chars("mwMW@")

/** An estimate of `text`'s width at `size`, with no font to measure. */
let width = (text, size) =>
  chars(text)->Array.reduce(0., (units, c) =>
    units +. (narrow->Array.includes(c) ? 0.37 : wide->Array.includes(c) ? 0.94 : 0.53)
  ) *. size

let defaultKind = "party"

let lineKeys = [
  ("message", "a message, and what it carries"),
  ("refused", "a refusal"),
  ("state", "the state of a party"),
]

type party = {name: string, kind: string}
type step =
  | Said({from: string, to: string, refused: bool, label: string})
  | Is({on: string, label: string})

let partyCell = RegExp.fromString("^([\\p{L}\\p{N}_.\\-]+)(?::([\\p{L}]+))?$", ~flags="u")
let moveLine = RegExp.fromString("^ *(\\S+) +(->|-x) +(\\S+)(?: +(.*))?$")
let stateLine = RegExp.fromString("^ *(\\S+) += +(.+)$")
let directiveLine = RegExp.fromString("^\\{(\\w+)\\}$")
let space = RegExp.fromString("\\s+")

let capture = (m, index) => m->RegExp.Result.matches->Array.get(index)->Option.flatMap(x => x)

let readText = (text, kinds: dict<string>) => {
  let parties = ref(None)
  let steps = []
  let legend = ref(false)
  text
  ->String.split("\n")
  ->Array.forEachWithIndex((raw, index) => {
    let line = String.trimEnd(raw)
    let at = `line ${Int.toString(index + 1)}`
    if String.trim(line) != "" && !String.startsWith(String.trim(line), "#") {
      switch RegExp.exec(directiveLine, String.trim(line)) {
      | Some(d) =>
        let name = capture(d, 0)->Option.getOr("")
        if name != "legend" {
          fail(`sequence: no directive {${name}}, ${at}`)
        }
        legend := true
      | None =>
        switch parties.contents {
        | None =>
          parties :=
            Some(
              line
              ->String.trim
              ->String.splitByRegExp(space)
              ->Array.map(cell => {
                let cell = cell->Option.getOr("")
                switch RegExp.exec(partyCell, cell) {
                | None => fail(`sequence: cannot read the party ${cell}, ${at}`)
                | Some(m) =>
                  let kind = capture(m, 1)->Option.getOr(defaultKind)
                  if kind != defaultKind && kinds->Dict.get(kind)->Option.isNone {
                    fail(`sequence: no kind called ${kind}, ${at}`)
                  }
                  {name: capture(m, 0)->Option.getOr(""), kind}
                }
              }),
            )
        | Some(_) =>
          switch RegExp.exec(stateLine, line) {
          | Some(m) =>
            steps->Array.push(
              Is({on: capture(m, 0)->Option.getOr(""), label: String.trim(capture(m, 1)->Option.getOr(""))}),
            )
          | None =>
            switch RegExp.exec(moveLine, line) {
            | None => fail(`sequence: cannot read the step at ${at}`)
            | Some(m) =>
              let from = capture(m, 0)->Option.getOr("")
              let to = capture(m, 2)->Option.getOr("")
              if from == to {
                fail(`sequence: a message runs between two parties, ${at}`)
              }
              steps->Array.push(
                Said({
                  from,
                  to,
                  refused: capture(m, 1) == Some("-x"),
                  label: String.trim(capture(m, 3)->Option.getOr("")),
                }),
              )
            }
          }
        }
      }
    }
  })
  let parties = switch parties.contents {
  | None => fail("sequence: no parties are named")
  | Some(parties) => parties
  }
  if Array.length(parties) < 2 {
    fail("sequence: a sequence runs between two parties at least")
  }
  let named = parties->Array.map(p => p.name)
  if Set.fromArray(named)->Set.size < Array.length(parties) {
    fail("sequence: a party is named twice")
  }
  // A step names parties, and only the first line declares them.
  steps->Array.forEach(step => {
    let ends = switch step {
    | Is({on}) => [on]
    | Said({from, to}) => [from, to]
    }
    ends->Array.forEach(end =>
      if !(named->Array.includes(end)) {
        fail(`sequence: no party called ${end}`)
      }
    )
  })
  (parties, steps, legend.contents)
}

type lane = {party: party, index: int, w: float, mutable centre: float, mutable x: float}

// A lane is as wide as its head. Two lanes are a fixed gap apart, unless a
// label between them needs more: then that gap alone widens, and a long
// label does not push the whole drawing.
let place = (parties: array<party>, steps) => {
  let lanes = parties->Array.mapWithIndex((party, index) => {
    party,
    index,
    w: Math.ceil(Math.max(laneLeast, width(party.name, 13.) +. pad *. 2.)),
    centre: 0.,
    x: 0.,
  })
  let lane = name => lanes->Array.find(l => l.party.name == name)->Option.getOrThrow
  let needs = Array.make(~length=Array.length(parties) - 1, 0.)
  steps->Array.forEach(step =>
    switch step {
    | Said({from, to, label}) if label != "" =>
      let low = Math.Int.min(lane(from).index, lane(to).index)
      let high = Math.Int.max(lane(from).index, lane(to).index)
      let need = (width(label, 11.) +. pad *. 2.) /. Int.toFloat(high - low)
      for gap in low to high - 1 {
        needs[gap] = Math.max(needs->Array.getUnsafe(gap), need)
      }
    | _ => ()
    }
  )
  lanes->Array.forEachWithIndex((l, index) => {
    let x = if index > 0 {
      let before = lanes->Array.getUnsafe(index - 1)
      let apart = Math.max(gapLeast +. (before.w +. l.w) /. 2., needs->Array.getUnsafe(index - 1))
      before.centre +. apart
    } else {
      l.w /. 2.
    }
    l.centre = Math.round(x)
    l.x = l.centre -. l.w /. 2.
  })
  (lanes, lane)
}

let unique = items => items->Array.reduce([], (seen, item) => seen->Array.includes(item) ? seen : [...seen, item])

/** The drawing of a sequence: its operations, placed. */
let read = (text, caption, kinds: dict<string>): drawing<SequenceOp.t> => {
  let (parties, steps, legend) = readText(text, kinds)
  let (lanes, lane) = place(parties, steps)
  let bottom = headHeight +. top +. Int.toFloat(Array.length(steps)) *. stepHeight

  let heads = lanes->Array.map(l => Head({
    kind: l.party.kind,
    x: l.x,
    y: 0.,
    width: l.w,
    height: headHeight,
    name: l.party.name,
  }))
  let lives = lanes->Array.map(l => Life({x: l.centre, top: headHeight, bottom}))
  let messages = []
  let states = []
  let reaches = []
  steps->Array.forEachWithIndex((step, index) => {
    let y = headHeight +. top +. Int.toFloat(index) *. stepHeight
    switch step {
    | Is({on, label}) =>
      let l = lane(on)
      let w = Math.ceil(width(label, 11.) +. pad *. 2.)
      let x = l.centre -. w /. 2.
      reaches->Array.push(x)
      reaches->Array.push(x +. w)
      states->Array.push(State({x, y: y -. stateHeight /. 2., width: w, height: stateHeight, text: label}))
    | Said({from, to, refused, label}) =>
      let from = lane(from).centre
      let to = lane(to).centre
      messages->Array.push(
        Message({
          from,
          to,
          y,
          refused,
          label: label == "" ? None : Some({x: Math.round((from +. to) /. 2.), y: y -. labelUp, text: label}),
        }),
      )
    }
  })

  let right = lanes->Array.reduce(0., (most, l) => Math.max(most, l.x +. l.w))
  // A state box that reaches past the outer lanes is part of the drawing:
  // the frame holds it instead of cutting it.
  let left = Math.minMany([0., ...reaches])
  let w = Math.maxMany([right, ...reaches]) -. left

  let keys = if legend {
    let used = parties->Array.map(p => p.kind)->unique->Array.filter(kind => kind != defaultKind)
    let lines =
      steps
      ->Array.map(step =>
        switch step {
        | Is(_) => "state"
        | Said({refused: true}) => "refused"
        | Said(_) => "message"
        }
      )
      ->unique
    [
      ...used->Array.map(kind => {kind, text: kinds->Dict.get(kind)->Option.getOr(kind), move: false}),
      ...lines->Array.map(kind => {
        kind,
        text: lineKeys->Array.find(((k, _)) => k == kind)->Option.mapOr("", Pair.second),
        move: false,
      }),
    ]
  } else {
    []
  }
  {
    ops: [
      Frame({left: left -. margin, top: -.margin, width: w +. margin *. 2., height: bottom +. margin *. 2.}),
      ...heads,
      ...lives,
      ...messages,
      ...states,
    ],
    caption,
    keys,
  }
}

let n = Float.toString

// A kind of the project's reads its colour from `--tone-<kind>`.
let tone = kind => kind == defaultKind ? "" : ` style="--tone: var(--tone-${kind}, var(--blocks-ink))"`
let escape = Html.escape

let tips = `<defs><marker id="sequence-tip" viewBox="0 0 14 10" refX="13" refY="5" markerWidth="14" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto"><path class="sequence__tip" d="M 0 0 L 14 5 L 0 10 L 3.8 5 z" /></marker><marker id="sequence-cross" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="10" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto"><path class="sequence__cross" d="M 1.5 1.5 L 8.5 8.5 M 8.5 1.5 L 1.5 8.5" /></marker></defs>`

/** The SVG of a sequence, painted from its operations. */
let render = (drawing: drawing<SequenceOp.t>) => {
  let pick = f => drawing.ops->Array.filterMap(f)->Array.join("")
  let frame = drawing.ops->Array.findMap(op =>
    switch op {
    | Frame(f) => Some(f)
    | _ => None
    }
  )->Option.getOrThrow
  let lives = pick(op =>
    switch op {
    | Life({x, top, bottom}) =>
      Some(`<line class="sequence__life" x1="${n(x)}" y1="${n(top)}" x2="${n(x)}" y2="${n(bottom)}" />`)
    | _ => None
    }
  )
  let heads = pick(op =>
    switch op {
    | Head({kind, x, y, width, height, name}) =>
      Some(
        `<g class="sequence__head sequence__head--${kind}"${tone(kind)}><rect x="${n(x)}" y="${n(y)}" width="${n(width)}" height="${n(height)}" rx="7" /><text x="${n(x +. width /. 2.)}" y="${n(y +. height /. 2. +. 4.)}" text-anchor="middle">${escape(name)}</text></g>`,
      )
    | _ => None
    }
  )
  let lines = pick(op =>
    switch op {
    | Message({from, to, y, refused, label}) =>
      let text = label->Option.mapOr("", l => l.text)
      Some(
        `<path class="sequence__message${refused ? " sequence__message--refused" : ""}" marker-end="url(#${refused ? "sequence-cross" : "sequence-tip"})" d="M ${n(from)} ${n(y)} L ${n(to)} ${n(y)}" data-step="${escape(text)}" />`,
      )
    | _ => None
    }
  )
  let boxes = pick(op =>
    switch op {
    | State({x, y, width, height, text}) =>
      Some(
        `<g class="sequence__state"><rect x="${n(x)}" y="${n(y)}" width="${n(width)}" height="${n(height)}" rx="6" /><text x="${n(x +. width /. 2.)}" y="${n(y +. height /. 2. +. 4.)}" text-anchor="middle">${escape(text)}</text></g>`,
      )
    | _ => None
    }
  )
  let notes = pick(op =>
    switch op {
    | Message({refused, label: Some({x, y, text})}) =>
      Some(
        `<text class="sequence__label${refused ? " sequence__label--refused" : ""}" text-anchor="middle" x="${n(x)}" y="${n(y)}">${escape(text)}</text>`,
      )
    | _ => None
    }
  )
  let label = drawing.caption->Option.getOr("A sequence")
  let title = drawing.caption->Option.mapOr("", c => `<span class="sequence__title">${escape(c)}</span>`)
  let keyed =
    drawing.keys == []
      ? ""
      : `<span class="sequence__keys">${drawing.keys
          ->Array.map(({kind, text}) => `<span class="sequence__key sequence__key--${kind}"${lineKeys->Array.some(((k, _)) => k == kind) ? "" : tone(kind)}>${escape(text)}</span>`)
          ->Array.join("")}</span>`
  let under = title ++ keyed == "" ? "" : `<figcaption class="sequence__caption">${title}${keyed}</figcaption>`
  `<figure class="sequence"><svg class="sequence__svg" viewBox="${n(frame.left)} ${n(frame.top)} ${n(frame.width)} ${n(frame.height)}" width="${n(frame.width)}" height="${n(frame.height)}" role="img" aria-label="${escape(label)}">${tips}${lives}${heads}${lines}${boxes}${notes}</svg>${under}</figure>`
}
