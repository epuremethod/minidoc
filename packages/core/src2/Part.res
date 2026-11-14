// A part of the page that a component draws: an element of the template
// that names it in `data-component`, or `<nav>`, which is `menu`. minidoc
// gives a component plain values, `page` and `pages`, and draws it again
// when they change: a page added, a title renamed, a heading typed.

type heading = {level: int, text: string, slug: string}

/** The current page: its title, its address, and its headings. */
type page = {title: string, href: string, headings: array<heading>}

/** A page of the site, in the menu's order. */
type link = {title: string, href: string}

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
  let pages = site.pages->Array.map(({title, href}) => {title, href})
  let title = site.pages->Array.find(one => one.href == current)->Option.mapOr("", one => one.title)
  let headings = outline.headings->Array.map(({level, text, slug}) => {level, text, slug})
  React.createElement(component, {page: {title, href: current, headings}, pages})
}
