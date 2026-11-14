// A page's markdown as the editor's section, and the section written back.
//
// The editor's `Page` reads and writes the file. minidoc names its own blocks,
// a drawing and a `:::` block that is no callout of the site, and holds back
// a source that it refuses.

module Scan = MinidocBlocks.Scan
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

/** The callout kinds of a site, which the editor draws in place. */
let kinds = options => MinidocBlocks.Blocks.callouts(options)->Array.map(Pair.first)

/** The `:::` blocks minidoc draws, by key, with their format: a plan is edited where it stands. */
let blocks = options =>
  MinidocBlocks.Blocks.keys(options)
  ->Array.map(key => (key, key == "plan" ? planFormat : blockFormat))
  ->Dict.fromArray

/** A page's markdown, read as the editor's section. */
let read = (text: string, ~options: MinidocBlocks.Blocks.options): t => {
  let file = Editor.Page.read(text, ~kinds=kinds(options), ~blocks=blocks(options))
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
