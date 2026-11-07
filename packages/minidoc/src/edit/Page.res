// A page's markdown as the editor's section, and the section written back.
//
// minidoc reads the markdown as CommonMark groups it: a paragraph, a `- `
// item and a `#` to `###` title are each one block of the editor, with
// one id, however the file wraps them. Every other block, a table, a
// numbered list, a quote, a `####` title, a code block or a `:::` block,
// is an atom of minidoc's, which holds its source exactly. The frontmatter
// and the blank lines between blocks are kept aside, as they are.
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

/** A block of the file: the blank lines before it, and its own lines. */
type kept = {gap: array<string>, lines: array<string>, kind: kind}

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

/** The blocks of a run of markdown with no `:::` block, as line ranges of the run. */
let grouped = (md, lines: array<string>): array<(int, int, kind, string)> => {
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
      | (kind, Some((start, end))) =>
        out->Array.push((start, end, Atom, ""))
        walk(String.endsWith(kind, "_open") ? closing(i, kind) + 1 : i + 1)
      }
    }
  walk(0)
  out
}

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
  // The blocks of the file, as line ranges.
  let found: array<(int, int, kind, string)> = []
  let run = ref(0)
  let flush = upto => {
    grouped(md, lines->Array.slice(~start=run.contents, ~end=upto))->Array.forEach(((start, end, kind, text)) =>
      found->Array.push((run.contents + start, run.contents + end, kind, text))
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
          found->Array.push((i, end + 1, Atom, ""))
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
  found->Array.forEachWithIndex(((start, end, kind, text), index) => {
    let id = `b${Int.toString(index)}`
    let own = lines->Array.slice(~start, ~end)
    blocks->Dict.set(id, {gap: lines->Array.slice(~start=at.contents, ~end=start), lines: own, kind})
    at := end
    switch kind {
    | Text(form) => rows->Array.push((id, Form.write(form, escape(text))))
    | Atom =>
      let source = own->Array.join("\n")
      let format = own->Array.get(0)->Option.mapOr(false, isPlan) ? planFormat : blockFormat
      let atom = `a${Int.toString(index)}`
      atoms->Array.push({Section.id: atom, format, value: JSON.String(source), placement: Dict.make()})
      rows->Array.push((id, `:: {{${atom}}}`))
    }
  })
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

/**
 The page's markdown, from the section the editor holds. `reads` says
 whether minidoc reads an atom's source: one it refuses is written as the
 last source it read.
*/
let write = (page: t, section: Section.t, ~reads: string => bool): string => {
  let sources = section.atoms->Array.map(atom => (atom.id, atom.value))->Dict.fromArray
  let out = []
  let previous = ref(None)
  section.blocks->Array.forEach(((id, row)) => {
    let atom = switch RegExp.exec(display, row) {
    | Some(m) => Some(Scan.capture(m, 0))
    | None => None
    }
    let (form, text) = Form.read(row)
    let (gap, lines) = switch (page.blocks->Dict.get(id), atom) {
    | (kept, Some(atom)) =>
      let source = switch sources->Dict.get(atom)->Option.flatMap(JSON.Decode.string) {
      | Some(source) if reads(source) =>
        page.good->Dict.set(atom, source)
        source
      | _ => page.good->Dict.get(atom)->Option.getOr("")
      }
      let lines = switch kept {
      | Some(kept) if kept.lines->Array.join("\n") == source => kept.lines
      | _ => source->String.split("\n")
      }
      (kept->Option.mapOr(["" ], kept => kept.gap), lines)
    | (Some(kept), None) =>
      let lines = switch kept.kind {
      | _ if page.given->Dict.get(id) == Some(row) => kept.lines
      | Text(was) if was == form => rebroken(kept.lines, unescape(text), ~form)
      | _ => fresh(form, text)
      }
      (kept.gap, lines)
    | (None, None) =>
      let gap = switch (previous.contents, form) {
      | (None, _) => []
      | (Some(Editor.Doc.Item), Item) => []
      | _ => [""]
      }
      (gap, fresh(form, text))
    }
    let gap = out->Array.length == 0 && page.blocks->Dict.get(id)->Option.isNone ? [] : gap
    gap->Array.forEach(line => out->Array.push(line))
    lines->Array.forEach(line => out->Array.push(line))
    previous := Some(atom->Option.isSome ? Editor.Doc.Display : form)
  })
  page.tail->Array.forEach(line => out->Array.push(line))
  page.front ++ out->Array.join("\n")
}
