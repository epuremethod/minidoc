// A part of the page that a component draws: an element of the template
// that names it in `data-component`, or `<nav>`, which is `menu`. minidoc
// gives a component plain values, `page` and `pages`, and draws it again
// when they change: a page added, a title renamed, a heading typed, a value
// of a frontmatter set.

type heading = {level: int, text: string, slug: string}

/** The current page: its title, its address, its headings, its frontmatter, and its sections. */
type page = {
  title: string,
  href: string,
  headings: array<heading>,
  front: dict<JSON.t>,
  sections: array<Site.section>,
}

/** A page of the site, in the menu's order: its address is relative to the current page. */
type link = {title: string, href: string, nav?: string, front: dict<JSON.t>}

type given = {page: page, pages: array<link>}

type component = React.component<given>

/** The attribute that names a part's component. */
let attribute = "data-component"

/** The component of `<nav>` when it names none. */
let menu = "menu"

/** A part: it reads the site and the headings through tilia, and hands the component their values. */
@react.component
let make = (~component: component, ~site: Site.t, ~current: string, ~outline: Outline.t) => {
  TiliaReact.useTilia()
  let href = Site.relative(~from=current, ...)
  let pages = site.pages->Array.map(({title, href: to_, ?nav, front}) => {title, href: href(to_), ?nav, front})
  let page = switch site.pages->Array.find(one => one.href == current) {
  | Some(one) => {
      title: one.title,
      href: href(current),
      headings: Outline.page(one, outline.files)->Array.map(({level, text, slug}) => {level, text, slug}),
      front: one.front,
      sections: one.sections,
    }
  | None => {title: "", href: href(current), headings: [], front: Dict.make(), sections: []}
  }
  React.createElement(component, {page, pages})
}
