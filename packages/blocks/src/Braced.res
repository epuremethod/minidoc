// A name or a label that carries attributes, the same in every drawing:
// `{Attribution, color red, active}`. The first item is the text, and may
// hold spaces; each item after a comma is an attribute. A plain word is a
// text with no attribute.

let fail = Html.fail

/** The words of a line. A word in braces keeps all that the braces hold, spaces too. */
let words = (line, ~block, ~at) => {
  let found = []
  let rest = ref(String.trim(line))
  while rest.contents != "" {
    let text = rest.contents
    let from = if String.startsWith(text, "{") {
      switch String.indexOfFrom(text, "}", 1) {
      | -1 => fail(`${block}: a brace is not closed, ${at}`)
      | close => close + 1
      }
    } else {
      0
    }
    let stop = switch String.searchOpt(String.slice(text, ~start=from), /\s/) {
    | Some(space) => from + space
    | None => String.length(text)
    }
    found->Array.push(String.slice(text, ~start=0, ~end=stop))
    rest := String.trimStart(String.slice(text, ~start=stop))
  }
  found
}

type t = {text: string, attributes: array<string>}

/** A word as written: `{a b, x, y}` is the text `a b` with the attributes `x` and `y`. */
let read = (word, ~block, ~at) =>
  if String.startsWith(word, "{") && String.endsWith(word, "}") {
    let items =
      word
      ->String.slice(~start=1, ~end=String.length(word) - 1)
      ->String.split(",")
      ->Array.map(String.trim)
    switch items {
    | [] | [""] => fail(`${block}: a name in braces is empty, ${at}`)
    | _ => {
        text: items->Array.getUnsafe(0),
        attributes: items->Array.slice(~start=1)->Array.filter(a => a != ""),
      }
    }
  } else {
    {text: word, attributes: []}
  }

/** The hues of the palette. Each theme gives `--hue-<name>` for each. */
let hues = ["grey", "red", "orange", "yellow", "green", "teal", "blue", "purple"]

// FNV-1a over the UTF-16 code units of the text, as a 32-bit unsigned number.
let fnv: string => int = %raw(`(text) => {
  let h = 0x811c9dc5
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i)
    h = Math.imul(h, 0x01000193) >>> 0
  }
  return h
}`)

/** A hue from a word: a hue's own name, or the word hashed into the palette. The same word gives the same hue on every page. */
let hue = word => {
  let word = String.toLowerCase(word)
  hues->Array.includes(word) ? word : hues->Array.getUnsafe(mod(fnv(word), Array.length(hues)))
}

/** The style that gives a drawn part its hue. */
let tone = hue => `--tone: var(--hue-${hue})`

let colorAttribute = RegExp.fromString("^color\\s+(\\S+)$")

/** The hue a `color <word>` attribute asks for. */
let color = attribute =>
  RegExp.exec(colorAttribute, attribute)
  ->Option.flatMap(m => m->RegExp.Result.matches->Array.get(0)->Option.flatMap(x => x))
  ->Option.map(hue)

/** What a name carries, from all its mentions. */
type marks = {color: option<string>, active: bool, kind: option<string>, tenant: option<string>}

let none = {color: None, active: false, kind: None, tenant: None}

/**
 * Add a mention's marks to those a name already has. A mention may give a
 * mark the others do not; two mentions that give one mark two values are
 * refused.
 */
let merge = (dict: dict<marks>, name, marks: marks, ~block, ~at) => {
  let was = dict->Dict.get(name)->Option.getOr(none)
  let one = (a, b, what) =>
    switch (a, b) {
    | (Some(a), Some(b)) if a != b => fail(`${block}: ${name} has two ${what}, ${at}`)
    | (Some(_), _) => a
    | (None, b) => b
    }
  dict->Dict.set(
    name,
    {
      color: one(was.color, marks.color, "colours"),
      active: was.active || marks.active,
      kind: one(was.kind, marks.kind, "kinds"),
      tenant: one(was.tenant, marks.tenant, "tenants"),
    },
  )
}

let kindWord = RegExp.fromString("^[\\p{L}]+$", ~flags="u")
let tenantWord = RegExp.fromString("^#([\\p{L}\\p{N}_.\\-]+)$", ~flags="u")

/**
 * The marks of a name's attributes. `takes` names what this block reads:
 * `active`, `color`, `tenant`, and the kinds it declares. A word that looks
 * like a kind but is not declared is refused as a kind.
 */
let marks = (
  name,
  attributes,
  ~block,
  ~at,
  ~active=false,
  ~tenant=false,
  ~kinds: option<dict<string>>=?,
) =>
  attributes->Array.reduce(none, (m, attribute) =>
    switch (attribute, color(attribute), RegExp.exec(tenantWord, attribute)) {
    | ("active", _, _) if active => {...m, active: true}
    | (_, Some(hue), _) => {...m, color: Some(hue)}
    | (_, _, Some(t)) if tenant => {
        ...m,
        tenant: t->RegExp.Result.matches->Array.get(0)->Option.flatMap(x => x),
      }
    | (word, _, _) if RegExp.test(kindWord, word) && kinds->Option.isSome =>
      if kinds->Option.flatMap(k => k->Dict.get(word))->Option.isNone {
        fail(`${block}: no kind called ${word}, ${at}`)
      }
      {...m, kind: Some(word)}
    | (word, _, _) => fail(`${block}: ${name} cannot take ${word}, ${at}`)
    }
  )

let placeAttribute = RegExp.fromString("^([01](?:\\.\\d+)?)(?:\\s+(left|right))?$|^(left|right)$")

/**
 * A label as written after a line. In braces, its attributes say where it
 * sits, `0.2`, on which side, `0.2 right` or `right`, its kind, a word the
 * block declares, and its colour: `{refuse, 0.4, fail, color red}`. A label
 * sits in the middle of its line by default.
 */
let label = (said, ~block, ~at, ~kinds: dict<string>) => {
  let said = String.trim(said)
  let {text, attributes} = read(said, ~block, ~at)
  attributes->Array.reduce((text, 0.5, false, None, None), ((text, where, right, kind, hue), attribute) =>
    switch (RegExp.exec(placeAttribute, attribute), color(attribute)) {
    | (_, Some(hue)) => (text, where, right, kind, Some(hue))
    | (Some(m), None) =>
      let part = index => m->RegExp.Result.matches->Array.get(index)->Option.flatMap(x => x)
      let side = part(1)->Option.orElse(part(2))
      (
        text,
        part(0)->Option.flatMap(Float.fromString)->Option.getOr(where),
        side->Option.mapOr(right, s => s == "right"),
        kind,
        hue,
      )
    | (None, None) if RegExp.test(kindWord, attribute) =>
      if kinds->Dict.get(attribute)->Option.isNone {
        fail(`${block}: no kind called ${attribute}, ${at}`)
      }
      (text, where, right, Some(attribute), hue)
    | (None, None) => fail(`${block}: a label cannot take ${attribute}, ${at}`)
    }
  )
}
