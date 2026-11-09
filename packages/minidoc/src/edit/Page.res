// A page's markdown as the editor's section, and the section written back.
//
// The editor's `Page` reads and writes the file. minidoc names its own blocks,
// a drawing and a `:::` block that is no callout of the site, and holds back
// a source that it refuses.

module Scan = EpureBlocks.Scan
module Section = Editor.Section

/** The format of a block the editor draws through minidoc. */
let blockFormat = Editor.Page.format

/** The format of a plan, which is edited where it stands. */
let planFormat = "plan"

type t = {
  file: Editor.Page.t,
  /** The section as minidoc read it. */
  section: Section.t,
  /** The last source of each atom that minidoc read. A source it refuses is not written. */
  good: dict<string>,
}

/** The format of a block that minidoc owns, from the block's opening line. */
let owned = (line, ~kinds: array<string>, ~drawings: array<string>) =>
  switch RegExp.exec(Scan.colonLine, line) {
  | Some(m) =>
    switch Scan.split(Scan.capture(m, 1))->Pair.first {
    | "plan" => Some(planFormat)
    | word => kinds->Array.includes(word) ? None : Some(blockFormat)
    }
  | None =>
    RegExp.exec(Scan.codeLine, line)->Option.flatMap(m =>
      drawings->Array.includes(Scan.split(Scan.capture(m, 1))->Pair.first) ? Some(blockFormat) : None
    )
  }

/** A page's markdown, read as the editor's section. */
let read = (text: string, ~options: EpureBlocks.Blocks.options): t => {
  let kinds = EpureBlocks.Blocks.callouts(options)->Array.map(Pair.first)
  let drawings = EpureBlocks.Blocks.drawings(options)
  let file = Editor.Page.read(text, ~opaque=owned(_, ~kinds, ~drawings))
  let good =
    file.section.atoms
    ->Array.map(atom => (atom.id, atom.value->JSON.Decode.string->Option.getOr("")))
    ->Dict.fromArray
  {file, section: file.section, good}
}

/** The section as the editor hands it back when nobody changed it. */
let held = (page: t) => Editor.Storage.write(Editor.Storage.read(page.section), ~id="page")

/**
 The page's markdown, from the section the editor holds. `reads` says
 whether minidoc reads an atom's source: one it refuses is written as the
 last source it read.
*/
let write = (page: t, section: Section.t, ~reads: string => bool): string => {
  let atoms = section.atoms->Array.map(atom =>
    switch atom.value->JSON.Decode.string {
    | Some(source) if reads(source) =>
      page.good->Dict.set(atom.id, source)
      atom
    | _ => {...atom, value: String(page.good->Dict.get(atom.id)->Option.getOr(""))}
    }
  )
  Editor.Page.write(page.file, {...section, atoms})
}
