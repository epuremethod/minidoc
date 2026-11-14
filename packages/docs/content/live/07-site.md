---
slug: site
nav: The site
title: The site around the pages
---
A site is more than its pages: a menu that marks the current page, the
list of the other pages, a home page with a layout of its own, and
outputs that are not HTML. Each is a reading of the carved site, in a
layout. See [The state](#state).

### Which files are pages

The config takes a glob of the pages: `pages: "content/*.md"`. Each file
it names is a page, with the HTML file of its slug. A file that a page
names in `sections` is a section of that page, and not a page of its
own. The pages are in the order of their file names, as the sections
are: `01-guide.md`, `02-api.md`, `03-blocks.md`. `index.md` is the home
page, written to `index.html`. A page with `menu: false` in its
frontmatter has `inMenu` false.

### The menu, and the current page

A layout receives `site` and `page`. Each page gives its `href`, its
`nav` and its `title`. The current page is the one that is `page`, and
its sections make the contents under it.

```rescript
// Layout.res
let text = React.string

@react.component
let make = (~site: Minidoc.site<Vars.t>, ~page: Minidoc.page) =>
  <html lang=page.lang>
    <head>
      <title> {text(page.title)} </title>
      <link rel="stylesheet" href="./site.css" />
    </head>
    <body>
      <nav className="contents">
        <ol>
          {site.vars.menu
          ->Array.map(p =>
            <li key=p.slug>
              <a href=p.href ariaCurrent=?{p === page ? Some(#page) : None}> {text(p.nav)} </a>
              {p === page
                ? <ol>
                    {page.sections
                    ->Array.map(s =>
                      <li key=s.slug> <a href={"#" ++ s.slug}> {text(s.nav)} </a> </li>
                    )
                    ->React.array}
                  </ol>
                : React.null}
            </li>
          )
          ->React.array}
        </ol>
      </nav>
      <main>
        {page.sections
        ->Array.map(s => <section key=s.slug id=s.slug className="chapter"> s.body </section>)
        ->React.array}
      </main>
    </body>
  </html>
```

```jsx
// Layout.jsx
export const Layout = ({ site, page }) => (
  <html lang={page.lang}>
    <head>
      <title>{page.title}</title>
      <link rel="stylesheet" href="./site.css" />
    </head>
    <body>
      <nav className="contents">
        <ol>
          {site.vars.menu.map((p) => (
            <li key={p.slug}>
              <a href={p.href} aria-current={p === page ? "page" : undefined}>{p.nav}</a>
              {p === page && (
                <ol>
                  {page.sections.map((s) => (
                    <li key={s.slug}><a href={`#${s.slug}`}>{s.nav}</a></li>
                  ))}
                </ol>
              )}
            </li>
          ))}
        </ol>
      </nav>
      <main>
        {page.sections.map((s) => (
          <section key={s.slug} id={s.slug} className="chapter">{s.body}</section>
        ))}
      </main>
    </body>
  </html>
)
```

`nav` is the frontmatter's `nav`, or the title. Both are tilia values: a
renamed page or section changes the menu in each open page. A link to
another page loads that page's HTML, as a static site does. In `dev`,
the new page opens its own socket.

### A layout for each kind of page

`layouts` names the layouts. A page picks one with `layout` in its
frontmatter. A page with no `layout` takes `default`.

```rescript
layouts: dict{"default": Layout.make, "index": Home.make},
```

```js
layouts: { default: Layout, index: Home },
```

```markdown
---
title: minidoc
layout: index
---
A small documentation website generator.
```

### All layouts are React

A layout draws the whole document, from `<html>` down, with
`react-dom/server`. The page hydrates it as islands, as a template's
map does: see [the open questions](#open). A renamed page changes its
`<title>` through a tilia `observe`.

An output that is not HTML, such as `llms.txt` or a sitemap, is a plain
function of the site that returns text. It reads the same tilia values.
A file that the site only copies, such as a stylesheet or a font, is a
line of `copy`.

```rescript
outputs: dict{
  "llms.txt": site =>
    site.pages->Array.map(p => `- [${p.title}](${p.href})`)->Array.join("\n"),
},
copy: ["assets/site.css", "assets/fonts"],
```

```js
outputs: {
  "llms.txt": (site) => site.pages.map((p) => `- [${p.title}](${p.href})`).join("\n"),
},
copy: ["assets/site.css", "assets/fonts"],
```

::: proposed
**minidoc stays in ReScript, and a site writes ReScript or JavaScript**
minidoc's own code stays in ReScript, with its `.resi` and its
`index.d.ts`, as today. tilia and the editor have the same two faces, so
a site picks its language. The examples of this page show both,
ReScript first.

These docs move to ReScript, so minidoc reads its own types first.

Cost: `dev` bundles the site's module for the browser after ReScript
compiles it. A site in ReScript runs `rescript watch` beside `dev`.
:::
