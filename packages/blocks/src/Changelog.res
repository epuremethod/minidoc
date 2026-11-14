// A changelog: what each release adds, changes, fixes or removes. The
// `::: changelog` block holds its entries, or names the markdown file that
// holds them, by a path the site resolves from the page. `::: release`
// draws the last release alone.
//
// An entry is an item of the top list, `- YYYY-MM-DD **version**`, the
// newest first; `- Unreleased` holds the changes not released yet, before
// them. A change is an item under its entry, led by its kind, `Add`,
// `Change`, `Fix` or `Remove`, and ended by `**Breaking**` when it breaks.
// A change may go on over the lines indented under it. A file may start
// with a title and some text, which the block leaves out.

@@jsxConfig({version: 4, module_: "Draw"})

open Node

let entryLine = /^- (\d{4}-\d{2}-\d{2}) \*\*([^*\n]+)\*\*\s*$/
let unreleasedLine = /^- Unreleased\s*$/
let changeLine = /^  - (.*\S)\s*$/
let moreLine = /^ {4,}(\S.*?)\s*$/
let kindWord = /^(Add|Change|Fix|Remove)\b\s*(.*)$/
let breakingMark = /^(.*?)\s*\*\*Breaking\*\*\.?$/

let capture = (found, index) => found->RegExp.Result.matches->Array.get(index)->Option.flatMap(x => x)

let kindOf = word =>
  switch word {
  | "Add" => Add
  | "Fix" => Fix
  | "Remove" => Remove
  | _ => Change
  }

/** The class of a kind, and the word that leads its change. */
let kindName = kind =>
  switch kind {
  | Add => "add"
  | Change => "change"
  | Fix => "fix"
  | Remove => "remove"
  }
let kindText = kind =>
  switch kind {
  | Add => "Add"
  | Change => "Change"
  | Fix => "Fix"
  | Remove => "Remove"
  }

/** A change from its words: its kind, if it says one, and its breaking mark, if it ends with one. */
let changeOf = (text: string): change => {
  let (text, breaking) = switch RegExp.exec(breakingMark, text) {
  | Some(found) => (capture(found, 0)->Option.getOr(""), true)
  | None => (text, false)
  }
  switch RegExp.exec(kindWord, text) {
  | Some(found) => {
      kind: kindOf(capture(found, 0)->Option.getOr("")),
      said: true,
      breaking,
      text: capture(found, 1)->Option.getOr(""),
    }
  | None => {kind: Change, said: false, breaking, text}
  }
}

/**
 * The entries of a changelog's text. `loose`, for a file, leaves out what
 * comes before the first entry. `at` names a line of the text, from 0, in
 * an error.
 */
let entries = (source: string, ~loose: bool, ~at: int => string, ~empty: string): array<entry> => {
  let found: array<(option<string>, option<string>, array<array<string>>)> = []
  source
  ->String.split("\n")
  ->Array.forEachWithIndex((line, index) => {
    let fail = message => Html.fail(`${at(index)}: ${message}`)
    if String.trim(line) != "" {
      switch (RegExp.exec(entryLine, line), RegExp.test(unreleasedLine, line)) {
      | (Some(entry), _) => found->Array.push((capture(entry, 1), capture(entry, 0), []))
      | (None, true) =>
        if found->Array.length > 0 {
          fail("Unreleased comes before the first release")
        }
        found->Array.push((None, None, []))
      | (None, false) =>
        switch (found->Array.at(-1), RegExp.exec(changeLine, line), RegExp.exec(moreLine, line)) {
        | (Some((_, _, changes)), Some(change), _) =>
          changes->Array.push([capture(change, 0)->Option.getOr("")])
        | (Some((_, _, changes)), None, Some(more)) if changes->Array.length > 0 =>
          changes
          ->Array.at(-1)
          ->Option.forEach(lines => lines->Array.push(capture(more, 0)->Option.getOr("")))
        | (None, _, _) if loose => ()
        | _ =>
          fail(
            `neither an entry (- YYYY-MM-DD **version**) nor a change under it: ${String.trim(line)}`,
          )
        }
      }
    }
  })
  if found->Array.length == 0 {
    Html.fail(empty)
  }
  found->Array.map(((version, date, changes)) => {
    version,
    date,
    changes: changes->Array.map(lines => changeOf(lines->Array.join(" "))),
  })
}

/**
 * The node of a `::: changelog` or `::: release` block on `line`. Its info
 * is the path of a file, which `load` reads; with none, its body holds the
 * entries.
 */
let read = (~name, ~info, ~body, ~line, ~load: string => option<string>) => {
  let block = `::: ${name} on line ${Int.toString(line)}`
  let path = String.trim(info)
  let (file, entries) = if path == "" {
    (
      None,
      entries(
        body,
        ~loose=false,
        ~at=index => `::: ${name} on line ${Int.toString(line + 1 + index)}`,
        ~empty=`${block}: holds no entry`,
      ),
    )
  } else {
    if String.trim(body) != "" {
      Html.fail(`${block}: holds entries and names a file; keep one`)
    }
    switch load(path) {
    | None => Html.fail(`${block}: ${path} leads to no file`)
    | Some(text) => (
        Some(path),
        entries(
          text,
          ~loose=true,
          ~at=index => `${block}, ${path} line ${Int.toString(index + 1)}`,
          ~empty=`${block}: ${path} holds no entry`,
        ),
      )
    }
  }
  let last = name == "release"
  if last && !(entries->Array.some(entry => entry.version != None)) {
    Html.fail(`${block}: no release yet`)
  }
  Changelog({last, file, entries})
}

/** A date written in full in the page's lang: `14 November 2026`. */
let longDate: (string, string) => string = %raw(`(iso, lang) =>
  new Intl.DateTimeFormat(lang === "en" ? "en-GB" : lang, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" })
    .format(new Date(iso + "T00:00:00Z"))`)

let text = Draw.string

let drawChange = (md, change: change) =>
  <li
    className={`change change--${kindName(change.kind)}${change.breaking ? " change--breaking" : ""}`}>
    {change.said
      ? <>
          <span className="change__kind"> {text(kindText(change.kind))} </span>
          {text(" ")}
        </>
      : Draw.null}
    {Draw.raw(Markdown.renderInline(md, change.text, Markdown.env()))}
    {change.breaking
      ? <>
          {text(" ")}
          <span className="change__breaking"> {text("Breaking")} </span>
        </>
      : Draw.null}
  </li>

let drawEntry = (md, lang, entry: entry) =>
  <article
    className={entry.version == None
      ? "changelog__release changelog__unreleased"
      : "changelog__release"}>
    <p className="changelog__head">
      <span className="changelog__version"> {text(entry.version->Option.getOr("Unreleased"))} </span>
      {switch entry.date {
      | Some(date) =>
        <>
          {text(" ")}
          <time className="changelog__date" dateTime=date> {text(longDate(date, lang))} </time>
        </>
      | None => Draw.null
      }}
    </p>
    {entry.changes == []
      ? Draw.null
      : <ul className="changelog__changes">
          {entry.changes->Array.map(change => drawChange(md, change))->Draw.array}
        </ul>}
  </article>

/**
 * A changelog: the changes not released yet, the last release, then the
 * earlier ones in a closed details. With `last`, the last release alone,
 * as a line: `6.0.2, 14 November 2026`.
 */
let draw = (md, lang, ~last, entries: array<entry>) => {
  let released = entries->Array.filter(entry => entry.version != None)
  if last {
    switch released[0] {
    | Some({version, date}) =>
      <p className="release">
        <span className="release__version"> {text(version->Option.getOr(""))} </span>
        {switch date {
        | Some(date) =>
          <>
            {text(", ")}
            <time className="release__date" dateTime=date> {text(longDate(date, lang))} </time>
          </>
        | None => Draw.null
        }}
      </p>
    | None => Draw.null
    }
  } else {
    let unreleased = entries->Array.filter(entry => entry.version == None)
    let earlier = released->Array.slice(~start=1)
    <section className="changelog">
      {[...unreleased, ...released->Array.slice(~start=0, ~end=1)]
      ->Array.map(entry => drawEntry(md, lang, entry))
      ->Draw.array}
      {earlier == []
        ? Draw.null
        : <details className="changelog__all">
            <summary> {text(`Earlier releases (${Int.toString(Array.length(earlier))})`)} </summary>
            {earlier->Array.map(entry => drawEntry(md, lang, entry))->Draw.array}
          </details>}
    </section>
  }
}
