// The headings of a page, from the editor's document of each of its files:
// what a component gets as `page.headings`, and what `contents` draws. A heading's slug is
// its text, as on GitHub: `A date you can set` is `a-date-you-can-set`.
// Two headings with one text take `-1`, `-2` after the second and the third.

/** A heading as a file's text has it, before the page gives it a slug. */
type raw = {
  level: int,
  text: string,
  /** The editor's id of the heading's block. */
  block: string,
}

type heading = {
  level: int,
  text: string,
  slug: string,
  /** The id of the heading's element in the page, after `block-`: a link to the slug leads to it. */
  block: string,
}

/** The headings of each file of the page, which its editor sets at each change, and the components read. */
type t = {files: dict<array<raw>>}

/** The slug of a heading's text: lower case, letters, digits and hyphens, a hyphen for each space. */
let slug = (text: string) =>
  text
  ->String.trim
  ->String.toLowerCase
  ->String.replaceRegExp(/[^\p{L}\p{N}\s_-]/gu, "")
  ->String.replaceRegExp(/\s/g, "-")

/** The headings of a document, in order. */
let raws = (doc: Editor.Doc.t): array<raw> =>
  doc.blocks->Array.filterMap(block =>
    switch block.form {
    | Heading(level) => Some({level, text: block.content.text->String.replaceAll("​", "")->String.trim, block: block.id})
    | _ => None
    }
  )

/** What goes before the id of each block of a section's editor, so two files of a page never share an id. */
let prefix = (section: Site.section) => section.slug ++ "-"

/**
 The headings of a page, in order, each slug once over the whole page: its
 own, then each section's. A section is one heading: its first heading, or
 its title when it has none, with the section's slug. Its other headings
 take their own slugs.
*/
let page = (page: Site.page, files: dict<array<raw>>): array<heading> => {
  let taken = Dict.make()
  page.sections->Array.forEach(section => taken->Dict.set(section.slug, 0))
  let slugged = (~before="", {level, text, block}: raw) => {
    let base = slug(text)
    let slug = switch taken->Dict.get(base) {
    | None =>
      taken->Dict.set(base, 0)
      base
    | Some(count) =>
      taken->Dict.set(base, count + 1)
      `${base}-${Int.toString(count + 1)}`
    }
    {level, text, slug, block: before ++ block}
  }
  let of_ = file => files->Dict.get(file)->Option.getOr([])
  of_(page.file)
  ->Array.map(raw => slugged(raw))
  ->Array.concat(
    page.sections->Array.flatMap(section => {
      let before = prefix(section)
      let headings = of_(section.file)
      let first = switch headings->Array.get(0) {
      | Some({level, text, block}) => {level: Math.Int.max(2, level), text, slug: section.slug, block: before ++ block}
      | None => {level: 2, text: section.title, slug: section.slug, block: ""}
      }
      [first]->Array.concat(headings->Array.slice(~start=1)->Array.map(raw => slugged(~before, raw)))
    }),
  )
}

/** The headings as a component of the site sees them: no block id. */
let shown = (headings: array<heading>) =>
  headings->Array.map(({level, text, slug}) => {"level": level, "text": text, "slug": slug})
