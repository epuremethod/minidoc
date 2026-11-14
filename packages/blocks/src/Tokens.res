// The tokens a pane colours in a block's source: one pass over its lines,
// with no parse, so a source being typed is coloured too. Each token is a
// kind and its text; the text between tokens has the kind "". A block that
// has no tokens of its own gives none, and its source shows plain.
//
// The kinds: fence, key, caption, name, empty, brace, link, label, place,
// active, attr, column, type, example, comment, and hue-<hue> for a colour or
// a tenant, in the hue it gives.

type token = (string, string)

let fenceLine = RegExp.fromString("^(:{3,})(\\s*)(\\S*)(\\s*)(.*)$")
let closingLine = RegExp.fromString("^(\\s*)(:{3,})(\\s*)$")
let placeAttribute = RegExp.fromString("^([01](?:\\.\\d+)?)(?:\\s+(left|right))?$|^(left|right)$")
let colorAttribute = RegExp.fromString("^(color)(\\s+)(\\S+)$")
let tenantAttribute = RegExp.fromString("^#\\S+$")
// A name, braced or plain. A brace not yet closed runs to the end of the line.
let name = "(\\{[^}]*\\}?|\\S+)"

let part = (m, index) => m->RegExp.Result.matches->Array.get(index)->Option.flatMap(x => x)->Option.getOr("")

let push = (tokens: array<token>, kind, text) =>
  if text != "" {
    tokens->Array.push((kind, text))
  }

/** An attribute in braces, coloured by what it does. */
let attribute = (tokens, a) =>
  if a == "active" {
    tokens->push("active", a)
  } else if RegExp.test(tenantAttribute, a) {
    tokens->push(`hue-${Braced.hue(a->String.slice(~start=1))}`, a)
  } else if RegExp.test(placeAttribute, a) {
    tokens->push("place", a)
  } else {
    switch RegExp.exec(colorAttribute, a) {
    | Some(m) =>
      tokens->push("attr", part(m, 0))
      tokens->push("", part(m, 1))
      tokens->push(`hue-${Braced.hue(part(m, 2))}`, part(m, 2))
    | None => tokens->push("attr", a)
    }
  }

/** Text with its spaces kept apart, so that a token holds no space at either end. */
let spaced = (tokens, kind, text, each) => {
  let trimmed = String.trimStart(text)
  tokens->push("", String.slice(text, ~start=0, ~end=String.length(text) - String.length(trimmed)))
  let core = String.trimEnd(trimmed)
  each(tokens, kind, core)
  tokens->push("", String.slice(trimmed, ~start=String.length(core)))
}

/** A word in braces: its text, then each attribute after a comma. */
let braced = (tokens, word, ~text) => {
  let closed = String.endsWith(word, "}") && String.length(word) > 1
  let inner = String.slice(word, ~start=1, ~end=closed ? String.length(word) - 1 : String.length(word))
  tokens->push("brace", "{")
  inner
  ->String.split(",")
  ->Array.forEachWithIndex((item, index) => {
    if index == 0 {
      tokens->spaced(text, item, push)
    } else {
      tokens->push("brace", ",")
      tokens->spaced("", item, (tokens, _, a) => attribute(tokens, a))
    }
  })
  if closed {
    tokens->push("brace", "}")
  }
}

/** A word of a grid or a step: a dot, a name and its kind, or a name in braces. */
let word = (tokens, w, ~text="name") =>
  if w == "." {
    tokens->push("empty", w)
  } else if String.startsWith(w, "{") {
    tokens->braced(w, ~text)
  } else {
    switch String.indexOf(w, ":") {
    | at if at > 0 && text == "name" =>
      tokens->push("name", String.slice(w, ~start=0, ~end=at))
      tokens->push("brace", ":")
      tokens->push("attr", String.slice(w, ~start=at + 1))
    | _ => tokens->push(text, w)
    }
  }

let wordPattern = RegExp.fromString("\\{[^}]*\\}?|\\S+|\\s+", ~flags="g")

/** The words of a line, with the spaces between them. */
let words = (tokens, line) =>
  line
  ->String.match(wordPattern)
  ->Option.getOr([])
  ->Array.forEach(w => {
    let w = w->Option.getOr("")
    if String.trim(w) == "" {
      tokens->push("", w)
    } else {
      tokens->word(w)
    }
  })

/** A label after a line's two names: plain, or in braces with its place. */
let label = (tokens, said) =>
  if String.startsWith(said, "{") {
    tokens->braced(said, ~text="label")
  } else {
    tokens->push("label", said)
  }

/** A line between two names: a move, a message or a relation, and its label. */
let linked = (tokens, line, links) =>
  switch RegExp.exec(
    RegExp.fromString(`^(\\s*)${name}(\\s+)(${links})(\\s+)${name}(?:(\\s+)(.*))?$`),
    line,
  ) {
  | Some(m) =>
    tokens->push("", part(m, 0))
    tokens->word(part(m, 1))
    tokens->push("", part(m, 2))
    tokens->push("link", part(m, 3))
    tokens->push("", part(m, 4))
    tokens->word(part(m, 5))
    tokens->push("", part(m, 6))
    let said = part(m, 7)
    let core = String.trimEnd(said)
    tokens->label(core)
    tokens->push("", String.slice(said, ~start=String.length(core)))
    true
  | None => false
  }

let legendLine = RegExp.fromString("^(\\s*)\\{(legend)\\}(\\s*)$")
let stateLine = RegExp.fromString(`^(\\s*)${name}(\\s+)(=)(\\s+)(.*)$`)
let columnLine = RegExp.fromString(`^(\\s+)${name}(?:(\\s+)${name})?(?:(\\s+)(\\S.*?))?(\\s*)$`)
let groupLine = RegExp.fromString("^(\\s+)(-{3,})(?:(\\s+)(\\S.*?))?(\\s*)$")
let headLine = RegExp.fromString("^(\\S+)(\\s+)(#\\S+)(\\s*)$")

/** The tokens of one line of a block's body, after its fence. */
let body = (tokens, key, line, ~grid, ~first) =>
  switch RegExp.exec(legendLine, line) {
  | Some(m) =>
    tokens->push("", part(m, 0))
    tokens->push("brace", "{")
    tokens->push("attr", part(m, 1))
    tokens->push("brace", "}")
    tokens->push("", part(m, 2))
  | None if String.startsWith(String.trim(line), "#") && !(key == "model" && String.startsWith(line, " ")) =>
    tokens->push("comment", line)
  | None =>
    switch key {
    | "states" =>
      if grid || !linked(tokens, line, "<->|->") {
        tokens->words(line)
      }
    | "sequence" =>
      if first {
        tokens->words(line)
      } else if !linked(tokens, line, "->|-x") {
        switch RegExp.exec(stateLine, line) {
        | Some(m) =>
          tokens->push("", part(m, 0))
          tokens->word(part(m, 1))
          tokens->push("", part(m, 2))
          tokens->push("link", part(m, 3))
          tokens->push("", part(m, 4))
          tokens->push("label", part(m, 5))
        | None => tokens->words(line)
        }
      }
    | _ =>
      if grid {
        tokens->words(line)
      } else if (String.startsWith(line, " ") || String.startsWith(line, "\t")) && RegExp.test(groupLine, line) {
        // A group: its dashes, then its name, plain or in braces.
        switch RegExp.exec(groupLine, line) {
        | Some(m) =>
          tokens->push("", part(m, 0))
          tokens->push("fence", part(m, 1))
          tokens->push("", part(m, 2))
          let named = part(m, 3)
          String.startsWith(named, "{") ? tokens->braced(named, ~text="name") : tokens->push("name", named)
          tokens->push("", part(m, 4))
        | None => ()
        }
      } else if String.startsWith(line, " ") || String.startsWith(line, "\t") {
        switch RegExp.exec(columnLine, line) {
        | Some(m) =>
          // A part in braces holds spaces and its attributes, as any word in braces does.
          let piece = (kind, w) => String.startsWith(w, "{") ? tokens->braced(w, ~text=kind) : tokens->push(kind, w)
          tokens->push("", part(m, 0))
          piece("column", part(m, 1))
          tokens->push("", part(m, 2))
          piece("type", part(m, 3))
          tokens->push("", part(m, 4))
          let value = part(m, 5)
          String.endsWith(value, "}") ? piece("example", value) : tokens->push("example", value)
          tokens->push("", part(m, 6))
        | None => tokens->push("", line)
        }
      } else if !linked(tokens, line, "[>o|}]*--[o<|{]*|<-|\\.\\.>") {
        switch RegExp.exec(headLine, line) {
        | Some(m) =>
          tokens->push("name", part(m, 0))
          tokens->push("", part(m, 1))
          tokens->attribute(part(m, 2))
          tokens->push("", part(m, 3))
        | None => tokens->words(line)
        }
      }
    }
  }

/** The blocks that colour their source. */
let keys = ["states", "model", "sequence"]

/** The tokens of a block's source, or none when its block has no tokens of its own. */
let read = (source: string): option<array<token>> => {
  let lines = String.split(source, "\n")
  switch RegExp.exec(fenceLine, lines->Array.get(0)->Option.getOr("")) {
  | Some(m) if keys->Array.includes(part(m, 2)) =>
    let key = part(m, 2)
    let tokens = []
    tokens->push("fence", part(m, 0))
    tokens->push("", part(m, 1))
    tokens->push("key", key)
    tokens->push("", part(m, 3))
    tokens->push("caption", part(m, 4))
    let grid = ref(true)
    let first = ref(true)
    lines
    ->Array.slice(~start=1)
    ->Array.forEach(line => {
      tokens->push("", "\n")
      switch RegExp.exec(closingLine, line) {
      | Some(c) =>
        tokens->push("", part(c, 0))
        tokens->push("fence", part(c, 1))
        tokens->push("", part(c, 2))
      | None if String.trim(line) == "" =>
        tokens->push("", line)
        grid := false
      | None =>
        tokens->body(key, line, ~grid=grid.contents, ~first=first.contents)
        first := false
      }
    })
    // Plain text next to plain text is one piece.
    Some(
      tokens->Array.reduce([], (joined: array<token>, (kind, text)) =>
        switch joined->Array.at(-1) {
        | Some(("", before)) if kind == "" =>
          joined->Array.set(Array.length(joined) - 1, ("", before ++ text))
          joined
        | _ => [...joined, (kind, text)]
        }
      ),
    )
  | _ => None
  }
}
