---
slug: state
nav: The state
title: The state of the site, carved with tilia
---
The site is one tilia object, made with `carve`. The files are its only
state. Everything else is derived from them: the sections, the pages,
their titles, the menu, and each value that the site adds. A var in
braces of today becomes a property of this object, a real tilia value.
A reader of it, such as the layout's menu or a site block, draws again
when it changes, and only that reader.

::: model The site
Site File
Page Section

Site
  files     source   the sync
  pages     derived
  vars      derived  the site's
  save      derived  an action

File
  path      text     content/a.md
  version   int      5
  text      text

Section
  path      text
  doc       derived  read
  title     derived  first heading

Page
  slug      text     two-renders
  front     derived  frontmatter
  sections  derived  the glob

Site --o< File  files
Site --o< Page  pages
Page --o< Section  sections
File --o< Section  read
:::

### Four layers

1. **`files`** is a `source`. In `dev`, the watcher fills it. In a page,
   the socket fills it. A file is its path, its version, and its text or
   its blob.
2. **`sections`** are derived, one for each file, by the file's
   pipeline. The section's `title` is the text of its first heading.
3. **`pages`** are derived from the markdown files: the frontmatter, the
   sections that the glob names, the slug from the file name.
4. **The site's own values**, in `vars`, are derived too: a menu, a
   version, a count of scenarios. The site writes them as tilia features
   are written, with pure functions and `derived`.

`save` is the one action. It maps a section to its file through the
pipeline, puts the file in `files` at once, and sends it with the
version it starts from.

```rescript
// Vars.res: the site's own values, pure functions of the site
type t = {menu: array<Minidoc.page>, version: string}

let menu = (site: Minidoc.site<t>) => site.pages->Array.filter(p => p.inMenu)
let version = (site: Minidoc.site<t>) => Package.version(site->Minidoc.text("package.json"))

let carve = ({derived}: Minidoc.carving<t>) => {
  menu: derived(menu),
  version: derived(version),
}
```

```rescript
// Site.res: the same module runs in dev and in each page
let config: Minidoc.config<Vars.t> = {
  pages: "content/*.md",
  layouts: dict{"default": Layout.make},
  files: dict{
    "content/**/*.md": Minidoc.markdown,
    "content/**/*.{png,jpg,svg}": Minidoc.image,
    "../blocks/test/*.test.yaml": Fixture.pipeline,
    "../db/ROOT-TYPES.yaml": Minidoc.plain,
    "package.json": Minidoc.plain,
  },
  blocks: dict{"radif-diagram": RootTypes.block},
}

let editor = Minidoc.make(config, Vars.carve)
```

```js
// Vars.mjs
export const carve = ({ derived }) => ({
  menu: derived((site) => site.pages.filter((p) => p.inMenu)),
  version: derived((site) => JSON.parse(Minidoc.text(site, "package.json")).version),
})

// Site.mjs
export const editor = Minidoc.make(
  {
    pages: "content/*.md",
    layouts: { default: Layout },
    files: {
      "content/**/*.md": Minidoc.markdown,
      "content/**/*.{png,jpg,svg}": Minidoc.image,
      "../blocks/test/*.test.yaml": Fixture.pipeline,
      "../db/ROOT-TYPES.yaml": Minidoc.plain,
      "package.json": Minidoc.plain,
    },
    blocks: { "radif-diagram": RootTypes.block },
  },
  Vars.carve,
)
```

`Minidoc.make` takes the site's config and the carving of its own
values. It carves one object: `files`, `sections`, `pages` and `save`
are minidoc's, and `vars` holds the site's values. A value is typed in
ReScript: `site.vars.menu` is an array of pages, not a text in braces.
`Minidoc.text(site, path)` reads a file's text, and tilia tracks the
read.

The layout reads `site.vars.menu` and `page.title` through tilia's React
binding, so a renamed page changes the menu of each open page, and
nothing else.

The site's modules depend in one direction: `Vars`, then `Layout` and
`RootTypes`, then `Site`, then `Build`. `Build` runs in Node only. Every
other module runs in Node and in each page.

### The editor and the state

minidoc is a binding of the editor, as `@radif/editor` is. That binding
fills the editor's port with radif's rows, saves after a pause, and lands
the rows that other people write. minidoc fills the same port with files,
and the local sync takes the place of the radif client. The parts that
it uses already exist:

- **`Section.storage`** of `@epure/editor` is the port: `sections`,
  `update` and `merge`. `sections` comes from `site.sections`, `update`
  is `site.save`, and `merge` is the editor's three-way merge.
- **`View.prepare`** of `@tilia/editor` makes the state of one section.
  It is a tilia tree, so the carved site can hold one for each open
  section. **`View.make`** draws it.
- **`View.land`** takes a section that landed. It merges it with the
  typed text through the port's `merge`, and draws again only the blocks
  that changed. `Live.sync` keeps one stable tilia object for each atom,
  so an image that did not change is not drawn again.
- **`View.save`** saves when the editor's timing says so: at a pause for
  typing, at once for a split, a join or a move.
- **`Identity.read`** of `@epure/editor` reads a text with no ids against
  the last section. Each block that did not change keeps its id, so a
  file that changed on disk merges block by block.
- **`Rule.make`** gives a format its data (`parse`, `encode`, and an
  optional `merge`) and its view. A rule's loader is the setup of a
  tilia `source`, so it draws again when a value that it read changes.

The editor holds the text that the person typed since the last save. A
save puts it in `files` at once, so `title` and the menu follow after
the editor's pause, not after a round trip to `dev`.

::: proposed
**One carved site, run in dev and in each page; the sync carries files**
The pipelines and the derived values are pure functions of `files`. So
`dev` and each page compute the same values from the same files, and
the HTML of the build hydrates with no difference, by construction. The
sync then carries files only: a path, a version, and a text or a blob.

If you accept, [The local sync](#sync) changes: `dev` sends the file,
and the page maps it and merges it.

Rejected: map on the server, and sync the sections and the values. Each
derived value must then go through the socket, and a value that the
layout reads needs its own message. The page would show values it cannot
compute again.

Cost: a page loads the files that its values read, not only its own. A
pipeline or a derived value cannot use Node. A value that needs a
process, such as a git log, comes from a file that a script writes.
:::
