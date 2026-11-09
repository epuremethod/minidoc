// A page's markdown as the editor's section, and the section written back.
//
// minidoc reads the markdown as CommonMark groups it: a paragraph, a `- `
// item and a `#` to `###` title are each one block of the editor, with
// one id, however the file wraps them. A closed code fence that is not a
// drawing is the editor's code block, its lines as they are. A callout
// that holds only such blocks is the editor's callout: its start line, and
// its blocks behind `> `. Every other block, a table, a numbered list, a
// quote, a `####` title, a drawing or another `:::` block, is an atom of
// minidoc's, which holds its source exactly. The frontmatter and the blank lines
// between blocks are kept aside, as they are.
//
// Written back, a block nobody changed is its lines as they were. An
// edited paragraph keeps its line breaks after the same words, so the file
// changes only where the person typed.

module Markdown = EpureBlocks.Markdown
module Scan = EpureBlocks.Scan
module Form = Editor.Form
module Section = Editor.Section
module Storage = Editor.Storage

/** The format of a block the editor draws through minidoc. */
let blockFormat = "minidoc"

/** The format of a plan, which is edited where it stands. */
let planFormat = "plan"

type kind =
  | Text(Editor.Doc.form)
  | Atom
  /** A callout's start line. `close` is the lines after its last block, its `:::` included, and `upto` the line after them. */
  | Start({close: array<string>, upto: int})

/** A block of the file: the blank lines before it, its own lines, and whether it is in a callout. */
type kept = {gap: array<string>, lines: array<string>, kind: kind, inside: bool}

/** A block found in the file, as a range of its lines. */
type found = {start: int, end: int, kind: kind, text: string, inside: bool}

type t = {
  /** The frontmatter, with its fences and the line break after them. */
  front: string,
  blocks: dict<kept>,
  /** The blank lines after the last block. */
  tail: array<string>,
  /** The section as minidoc read it. */
  section: Section.t,
  /** Each text block as the editor writes it when nobody changed it. */
  given: dict<string>,
  /** The last source of each atom that minidoc read. A source it refuses is not written. */
  good: dict<string>,
}

let frontmatter = /^---\r?\n[\s\S]*?\r?\n---[ \t]*(\r?\n|$)/

// The editor reads `{{name}}` as one of its own references. In a page it
// is text.
let atomRefs = /(^|[^\\])\{\{/g
let escaped = /\\\{\{/g
// A code span keeps its text: the editor reads no reference in it.
let outsideCode: (string, string => string) => string = %raw(`(text, change) => {
  let out = "", at = 0
  for (const m of text.matchAll(/(\`+)[\s\S]*?[^\`]\1(?!\`)|(\`+)\2(?!\`)/g)) {
    out += change(text.slice(at, m.index)) + m[0]
    at = m.index + m[0].length
  }
  return out + change(text.slice(at))
}`)
let escape = text => text->outsideCode(part => part->String.replaceRegExp(atomRefs, "$1\\{{"))
let unescape = text => text->outsideCode(part => part->String.replaceRegExp(escaped, "{{"))

let blank = line => String.trim(line) == ""

type token = {
  @as("type") kind: string,
  markup: string,
  content: string,
  level: int,
  map: Nullable.t<array<int>>,
}
let tokens = (md, text): array<token> => Markdown.parse(md, text, Markdown.env())->Obj.magic

let space = /\s+/g
let joined = (content: string) => content->String.replaceRegExp(space, " ")->String.trim

// A bullet list the editor holds: `- ` items, each one paragraph at most.
let flat = (all: array<token>, from, to) =>
  all
  ->Array.slice(~start=from + 1, ~end=to)
  ->Array.every(t =>
    switch t.kind {
    | "list_item_open" | "list_item_close" => t.level == 1
    | "paragraph_open" | "paragraph_close" | "inline" => t.level <= 3 && t.level >= 2
    | _ => false
    }
  )

/**
 The code block of the fence at `start`, when the editor holds it: it
 opens at the line's start, it closes, and it is not one of the
 `drawings`. Its text is empty: its row is its lines.
*/
let code = (lines: array<string>, ~start, ~end, ~drawings: array<string>) =>
  switch RegExp.exec(Scan.codeLine, lines->Array.getUnsafe(start)) {
  | Some(m) =>
    let marker = Scan.capture(m, 0)
    let closed = Scan.fenceEnd(lines, start, marker) == end - 1 && end - 1 > start
    let language = Scan.split(Scan.capture(m, 1))->Pair.first
    switch Editor.Code.read(lines->Array.getUnsafe(start)) {
    | Some((form, _)) if closed && !(drawings->Array.includes(language)) => Some(Text(form))
    | _ => None
    }
  | None => None
  }

/** The blocks of a run of markdown with no `:::` block, as line ranges of the run. */
let grouped = (md, lines: array<string>, ~drawings): array<(int, int, kind, string)> => {
  let all = tokens(md, lines->Array.join("\n"))
  let out = []
  let range = (t: token) =>
    switch t.map->Nullable.toOption {
    | Some([start, end]) =>
      // A block's range may take the blank lines after it.
      let end = ref(end)
      while end.contents > start && blank(lines->Array.getUnsafe(end.contents - 1)) {
        end := end.contents - 1
      }
      Some((start, end.contents))
    | _ => None
    }
  let closing = (from, kind) => {
    let close = String.replace(kind, "_open", "_close")
    let rec go = i =>
      switch all->Array.get(i) {
      | None => i
      | Some(t) if t.kind == close && t.level == 0 => i
      | Some(_) => go(i + 1)
      }
    go(from + 1)
  }
  let rec walk = i =>
    switch all->Array.get(i) {
    | None => ()
    | Some(t) if t.level != 0 => walk(i + 1)
    | Some(t) =>
      switch (t.kind, range(t)) {
      | (_, None) => walk(i + 1)
      | ("paragraph_open", Some((start, end))) =>
        let inline = all->Array.getUnsafe(i + 1)
        out->Array.push((start, end, Text(Paragraph), joined(inline.content)))
        walk(closing(i, t.kind) + 1)
      | ("heading_open", Some((start, end)))
        if ["#", "##", "###"]->Array.includes(t.markup) =>
        let inline = all->Array.getUnsafe(i + 1)
        out->Array.push((start, end, Text(Heading(String.length(t.markup))), joined(inline.content)))
        walk(closing(i, t.kind) + 1)
      | ("bullet_list_open", Some((start, end))) =>
        let close = closing(i, t.kind)
        if t.markup == "-" && flat(all, i, close) {
          let rec items = j =>
            if j < close {
              let item = all->Array.getUnsafe(j)
              if item.kind == "list_item_open" {
                switch range(item) {
                | Some((from, to)) =>
                  let text = switch all->Array.get(j + 2) {
                  | Some(inline) if inline.kind == "inline" && (all->Array.getUnsafe(j + 1)).kind == "paragraph_open" =>
                    joined(inline.content)
                  | _ => ""
                  }
                  out->Array.push((from, to, Text(Item), text))
                | None => ()
                }
              }
              items(j + 1)
            }
          items(i + 1)
        } else {
          out->Array.push((start, end, Atom, ""))
        }
        walk(close + 1)
      | ("fence", Some((start, end))) =>
        out->Array.push((start, end, code(lines, ~start, ~end, ~drawings)->Option.getOr(Atom), ""))
        walk(i + 1)
      | (kind, Some((start, end))) =>
        out->Array.push((start, end, Atom, ""))
        walk(String.endsWith(kind, "_open") ? closing(i, kind) + 1 : i + 1)
      }
    }
  walk(0)
  out
}

/**
 The blocks in the callout that `lines` open, when the editor holds it: its
 start is `::: ` and one of `kinds`, and every block in it is text. `end`
 is the line that closes it.
*/
let callout = (md, lines: array<string>, ~start, ~end, ~kinds: array<string>, ~drawings) => {
  let opening = lines->Array.getUnsafe(start)
  let body = lines->Array.slice(~start=start + 1, ~end)
  let known = switch Editor.Callout.read(opening) {
  | Some((Callout({kind}), _)) => kinds->Array.includes(kind)
  | _ => false
  }
  let nested = body->Array.some(line =>
    switch RegExp.exec(Scan.colonLine, line) {
    | Some(m) => Scan.capture(m, 1) != ""
    | None => false
    }
  )
  if !known || nested {
    None
  } else {
    let blocks = grouped(md, body, ~drawings)
    blocks->Array.every(((_, _, kind, _)) => kind != Atom)
      ? Some(blocks->Array.map(((from, to, kind, text)) => {start: start + 1 + from, end: start + 1 + to, kind, text, inside: true}))
      : None
  }
}

/** A row in a callout: each of its lines behind `> `, or `>` alone when it is empty. */
let marks = row => row->String.split("\n")->Array.map(line => line == "" ? ">" : "> " ++ line)->Array.join("\n")

/** The plan of a `:::` block, when it is one. */
let isPlan = line =>
  switch RegExp.exec(Scan.colonLine, line) {
  | Some(m) => Scan.split(Scan.capture(m, 1))->Pair.first == "plan"
  | None => false
  }

/** A page's markdown, read as the editor's section. */
let read = (text: string, ~options: EpureBlocks.Blocks.options): t => {
  let front = switch RegExp.exec(frontmatter, text) {
  | Some(m) => RegExp.Result.fullMatch(m)
  | None => ""
  }
  let lines = text->String.slice(~start=String.length(front))->String.split("\n")
  let md = Markdown.make(options.markdown)
  let kinds = EpureBlocks.Blocks.callouts(options)->Array.map(Pair.first)
  let drawings = EpureBlocks.Blocks.drawings(options)
  // The blocks of the file, as line ranges.
  let found: array<found> = []
  let run = ref(0)
  let flush = upto => {
    grouped(md, lines->Array.slice(~start=run.contents, ~end=upto), ~drawings)->Array.forEach(((start, end, kind, text)) =>
      found->Array.push({start: run.contents + start, end: run.contents + end, kind, text, inside: false})
    )
  }
  let rec go = i =>
    switch lines->Array.get(i) {
    | None => flush(i)
    | Some(line) =>
      switch RegExp.exec(Scan.codeLine, line) {
      | Some(m) => go(Scan.fenceEnd(lines, i, Scan.capture(m, 0)) + 1)
      | None =>
        switch RegExp.exec(Scan.colonLine, line) {
        | Some(m) if Scan.capture(m, 1) != "" =>
          flush(i)
          let end = try Scan.blockEnd(lines, i, Scan.capture(m, 0), 1) catch {
          | _ => lines->Array.length - 1
          }
          let closed =
            end > i &&
            switch lines->Array.get(end)->Option.flatMap(line => RegExp.exec(Scan.colonLine, line)) {
            | Some(m) => Scan.capture(m, 1) == ""
            | None => false
            }
          switch closed ? callout(md, lines, ~start=i, ~end, ~kinds, ~drawings) : None {
          | Some(inside) =>
            let last = inside->Array.at(-1)->Option.mapOr(i + 1, block => block.end)
            let close = lines->Array.slice(~start=last, ~end=end + 1)
            found->Array.push({start: i, end: i + 1, kind: Start({close, upto: end + 1}), text: "", inside: false})
            inside->Array.forEach(block => found->Array.push(block))
          | None => found->Array.push({start: i, end: end + 1, kind: Atom, text: "", inside: false})
          }
          run := end + 1
          go(end + 1)
        | _ => go(i + 1)
        }
      }
    }
  go(0)
  let blocks = Dict.make()
  let atoms = []
  let rows = []
  let at = ref(0)
  // The line after the callout the last block was in, which the next
  // block outside it starts its gap from.
  let closing = ref(None)
  let leave = () => {
    closing.contents->Option.forEach(upto => at := upto)
    closing := None
  }
  found->Array.forEachWithIndex(({start, end, kind, text, inside}, index) => {
    if !inside {
      leave()
    }
    let id = `b${Int.toString(index)}`
    let own = lines->Array.slice(~start, ~end)
    blocks->Dict.set(id, {gap: lines->Array.slice(~start=at.contents, ~end=start), lines: own, kind, inside})
    at := end
    switch kind {
    | Start({upto}) =>
      closing := Some(upto)
      rows->Array.push((id, own->Array.join("")))
    | Text(form) =>
      let row = switch form {
      | Code(_) => own->Array.join("\n")
      | _ => Form.write(form, escape(text))
      }
      rows->Array.push((id, inside ? marks(row) : row))
    | Atom =>
      let source = own->Array.join("\n")
      let format = own->Array.get(0)->Option.mapOr(false, isPlan) ? planFormat : blockFormat
      let atom = `a${Int.toString(index)}`
      atoms->Array.push({Section.id: atom, format, value: JSON.String(source), placement: Dict.make()})
      rows->Array.push((id, `:: {{${atom}}}`))
    }
  })
  leave()
  let section: Section.t = {id: "page", blocks: rows, atoms, uses: []}
  let given = Storage.write(Storage.read(section), ~id="page").blocks->Dict.fromArray
  let good = atoms->Array.map(atom => (atom.id, atom.value->JSON.Decode.string->Option.getOr("")))->Dict.fromArray
  {front, blocks, tail: lines->Array.slice(~start=at.contents), section, given, good}
}

/** The section as the editor hands it back when nobody changed it. */
let held = (page: t) => Storage.write(Storage.read(page.section), ~id="page")

// ── Writing back ────────────────────────────────────────────────────────

let words = text => text->String.trim->String.splitByRegExp(/\s+/)->Array.filterMap(w => w)->Array.filter(w => w != "")

/** For each word of `a`, the word of `b` it matches in a longest common subsequence. */
let matched = (a: array<string>, b: array<string>) => {
  let rows = a->Array.length
  let columns = b->Array.length
  let table = Array.fromInitializer(~length=rows + 1, _ => Array.make(~length=columns + 1, 0))
  let cell = (i, j) => table->Array.getUnsafe(i)->Array.getUnsafe(j)
  for i in rows - 1 downto 0 {
    for j in columns - 1 downto 0 {
      table
      ->Array.getUnsafe(i)
      ->Array.setUnsafe(
        j,
        a->Array.getUnsafe(i) == b->Array.getUnsafe(j)
          ? cell(i + 1, j + 1) + 1
          : Math.Int.max(cell(i + 1, j), cell(i, j + 1)),
      )
    }
  }
  let found: array<option<int>> = Array.make(~length=rows, None)
  let i = ref(0)
  let j = ref(0)
  while i.contents < rows && j.contents < columns {
    if a->Array.getUnsafe(i.contents) == b->Array.getUnsafe(j.contents) {
      found->Array.setUnsafe(i.contents, Some(j.contents))
      i := i.contents + 1
      j := j.contents + 1
    } else if cell(i.contents + 1, j.contents) >= cell(i.contents, j.contents + 1) {
      i := i.contents + 1
    } else {
      j := j.contents + 1
    }
  }
  found
}

let lead = /^(\s*(?:#{1,3}|-)?\s*)(.*)$/

/** A line's start, its indent or its marker, and its words. */
let parts = (line, ~marked) =>
  switch marked ? RegExp.exec(lead, line) : RegExp.exec(/^(\s*)(.*)$/, line) {
  | Some(m) => (Scan.capture(m, 0), words(Scan.capture(m, 1)))
  | None => ("", words(line))
  }

// A word that would start another block when it starts a line.
let opener = /^([-+*>]|\d+[.)]|#{1,6}|:{3,}|`{3,}|~{3,}|=+)$/

/** The edited text, broken into lines after the same words as `before`. */
let rebroken = (before: array<string>, text: string, ~form: Editor.Doc.form) => {
  let lines = before->Array.mapWithIndex((line, i) => parts(line, ~marked=i == 0 && form != Paragraph))
  let old = lines->Array.flatMap(Pair.second)
  let fresh = words(text)
  let found = matched(old, fresh)
  // The new word each line but the last ends after.
  let breaks = []
  let seen = ref(0)
  lines->Array.forEachWithIndex(((_, own), i) => {
    let first = seen.contents
    seen := first + own->Array.length
    if i < lines->Array.length - 1 {
      let rec back = k =>
        if k < first {
          None
        } else {
          switch found->Array.getUnsafe(k) {
          | Some(j) => Some(j)
          | None => back(k - 1)
          }
        }
      switch back(seen.contents - 1) {
      | Some(j)
        if j < fresh->Array.length - 1 &&
        breaks->Array.at(-1)->Option.mapOr(true, ((last, _)) => j > last) &&
        !RegExp.test(opener, fresh->Array.getUnsafe(j + 1)) =>
        breaks->Array.push((j, i + 1))
      | _ => ()
      }
    }
  })
  let out = []
  let from = ref(0)
  let starts = [(-1, 0), ...breaks]
  starts->Array.forEachWithIndex(((_, line), k) => {
    let upto = switch starts->Array.get(k + 1) {
    | Some((next, _)) => next + 1
    | None => fresh->Array.length
    }
    let start = Pair.first(lines->Array.getUnsafe(line))
    out->Array.push(start ++ fresh->Array.slice(~start=from.contents, ~end=upto)->Array.join(" "))
    from := upto
  })
  out
}

let display = /^:: \{\{([^{}]+)\}\}$/

/** The text of a block the editor wrote, as the lines of the file. */
let fresh = (form: Editor.Doc.form, text) => [Form.lead(form) ++ unescape(text)]

/** A row of a block in a callout, each line behind `> `, without them. */
let marked = (row: string) => {
  let lines = row->String.split("\n")
  lines->Array.every(line => line == ">" || line->String.startsWith("> "))
    ? Some(lines->Array.map(line => line->String.slice(~start=2))->Array.join("\n"))
    : None
}

let isStart = (form: Editor.Doc.form) =>
  switch form {
  | Callout(_) => true
  | _ => false
  }

/** Whether a block is its row on the port, as a start or a code block is: neither the notation nor a line break touches it. */
let isPlain = (form: Editor.Doc.form) =>
  switch form {
  | Callout(_) | Code(_) => true
  | _ => false
  }

/**
 The page's markdown, from the section the editor holds. `reads` says
 whether minidoc reads an atom's source: one it refuses is written as the
 last source it read.
*/
let write = (page: t, section: Section.t, ~reads: string => bool): string => {
  let sources = section.atoms->Array.map(atom => (atom.id, atom.value))->Dict.fromArray
  let out = []
  let push = lines => lines->Array.forEach(line => out->Array.push(line))
  let previous = ref(None)
  // The lines that close the callout the last block is in, when it is in one.
  let open_ = ref(None)
  // Whether the last block is a callout's start.
  let started = ref(false)
  let close = () =>
    open_.contents->Option.forEach(lines => {
      push(lines)
      open_ := None
      previous := Some(Editor.Doc.Display)
    })
  section.blocks->Array.forEach(((id, row)) => {
    let (form, text) = Form.read(row)
    let start = isStart(form)
    // A block is in a callout when it is marked and the blocks above it,
    // up to a start, are marked too, as the editor reads it.
    let body = marked(row)
    if start || body->Option.isNone {
      close()
    }
    let inside = open_.contents->Option.isSome
    let first = started.contents
    let (own, form, text) = switch body {
    | Some(body) if !start =>
      let (form, text) = Form.read(body)
      (body, form, text)
    | _ => (row, form, text)
    }
    let atom = start ? None : switch RegExp.exec(display, Form.write(form, text)) {
    | Some(m) => Some(Scan.capture(m, 0))
    | None => None
    }
    let kept = page.blocks->Dict.get(id)
    // The gap of a block that moved into a callout or out of one.
    let made = () =>
      switch (previous.contents, form) {
      | _ if first => []
      | (None, _) => []
      | (Some(Editor.Doc.Item), Item) => []
      | _ => [""]
      }
    let gap = switch kept {
    | _ if first && inside => kept->Option.mapOr([], kept => kept.inside ? kept.gap : [])
    | Some(kept) if kept.inside == inside => kept.gap
    | _ => made()
    }
    let lines = switch (kept, atom) {
    | (_, Some(atom)) =>
      let source = switch sources->Dict.get(atom)->Option.flatMap(JSON.Decode.string) {
      | Some(source) if reads(source) =>
        page.good->Dict.set(atom, source)
        source
      | _ => page.good->Dict.get(atom)->Option.getOr("")
      }
      switch kept {
      | Some(kept) if kept.lines->Array.join("\n") == source => kept.lines
      | _ => source->String.split("\n")
      }
    | (Some(kept), None) =>
      switch kept.kind {
      | _ if page.given->Dict.get(id) == Some(row) => kept.lines
      | _ if isPlain(form) => own->String.split("\n")
      | Text(was) if was == form => rebroken(kept.lines, unescape(text), ~form)
      | _ => fresh(form, text)
      }
    | (None, None) => isPlain(form) ? own->String.split("\n") : fresh(form, text)
    }
    let gap = out->Array.length == 0 && kept->Option.isNone ? [] : gap
    push(gap)
    push(lines)
    previous := Some(atom->Option.isSome ? Editor.Doc.Display : form)
    started := start
    if start {
      open_ :=
        Some(
          switch kept {
          | Some({kind: Start({close})}) => close
          | _ => [":::"]
          },
        )
    }
  })
  close()
  page.tail->Array.forEach(line => out->Array.push(line))
  page.front ++ out->Array.join("\n")
}
