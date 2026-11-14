// The headings of a page, from the editor's document: what a component
// gets as `page.headings`, and what `contents` draws. A heading's slug is
// its text, as on GitHub: `A date you can set` is `a-date-you-can-set`.
// Two headings with one text take `-1`, `-2` after the second and the third.

type heading = {
  level: int,
  text: string,
  slug: string,
  /** The editor's id of the heading's block: a link to the slug leads to it. */
  block: string,
}

/** The page's headings, which the article sets at each change, and the components read. */
type t = {mutable headings: array<heading>}

/** The slug of a heading's text: lower case, letters, digits and hyphens, a hyphen for each space. */
let slug = (text: string) =>
  text
  ->String.trim
  ->String.toLowerCase
  ->String.replaceRegExp(/[^\p{L}\p{N}\s_-]/gu, "")
  ->String.replaceRegExp(/\s/g, "-")

/** The headings of a document, in order, each slug once. */
let of_ = (doc: Editor.Doc.t): array<heading> => {
  let taken = Dict.make()
  doc.blocks->Array.filterMap(block =>
    switch block.form {
    | Heading(level) =>
      let text = block.content.text->String.replaceAll("​", "")->String.trim
      let base = slug(text)
      let slug = switch taken->Dict.get(base) {
      | None =>
        taken->Dict.set(base, 0)
        base
      | Some(count) =>
        taken->Dict.set(base, count + 1)
        `${base}-${Int.toString(count + 1)}`
      }
      Some({level, text, slug, block: block.id})
    | _ => None
    }
  )
}

/** The headings as a component of the site sees them: no block id. */
let shown = (headings: array<heading>) =>
  headings->Array.map(({level, text, slug}) => {"level": level, "text": text, "slug": slug})
