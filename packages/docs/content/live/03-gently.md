---
slug: gently
nav: Complexity comes gently
title: Complexity comes gently
---
A person points minidoc at a folder of markdown files, and gets a site
that they can read and edit. Each thing that they add to the folder
gives them more control. They learn a level only when they need it.

| You add | You get |
| --- | --- |
| nothing | `minidoc notes/`: each markdown file is a page, with a sober style, a menu of the pages, and the editor |
| `index.html` with `<article>` and `<nav>` | your page and your styles: the markdown in `<article>`, the links in `<nav>`, the rest as you wrote it |
| `data-component` in `index.html`, and a `components/` folder | a part of your own in any element: the contents, a count of the pages, a diagram |
| a React layout | everything |

### Level 0: a folder

```sh
minidoc notes/
```

Each `.md` file of the folder is a page, in the order of the file names.
minidoc serves them with a default template: a sober, clean style, a
menu of the pages beside the text, the editor on the text, and a footer
with the previous and the next page, so you see where a page ends. A change
in the page writes the file, and a change of the file lands in the page.

The page is the editor's engine for one markdown text. A block that you
did not edit keeps its bytes, and so does the frontmatter: minidoc does
not draw it, and writes it back as it was. A table is edited in place,
cell by cell. When the file changes on disk while you type, the two
merge: each block keeps the words of the side that changed it, and the
words of a block changed on both sides merge. The frontmatter merges key
by key, and your value wins on a clash.

### Level 1: `index.html`

When the folder holds an `index.html`, it is the template. minidoc keeps
it as it is written, and fills three elements:

- `<article>` takes the page, drawn by the editor. Its own content is
  only an example, to see the template in a browser.
- `<nav>` takes a link to each page. The current page has
  `aria-current="page"`.
- `<title>` takes the page's title.

```html
<!doctype html>
<html lang="en">
<head>
  <title>Notes</title>
  <link rel="stylesheet" href="./notes.css">
</head>
<body>
  <header>My notes</header>
  <nav></nav>
  <article><p>An example of the text, to see the style.</p></article>
</body>
</html>
```

The editor's text uses the template's styles. So the editor must draw
plain HTML: `p`, `h2`, `ul`, `pre`, and no class that the template does
not know. That is [the open question](#open) about clean HTML, and level
1 depends on it.

### Level 2: components

A component draws a part of the page: the contents, a list of the
pages, the date of a release. Put an element in `index.html`, and name
the component in its `data-component`:

```html
<aside data-component="contents"></aside>
```

minidoc keeps the element and its attributes, so your styles still
apply, and draws the component in it. Each element that names a
component gets it, and the part follows each key: type a heading, and
the contents show it at once.

minidoc gives three components:

| Name | What it draws |
| --- | --- |
| `contents` | the page's `##` and `###` headings, each a link to its heading |
| `menu` | a link to each page, the current one marked: what `<nav>` gets |
| `pager` | a link to the previous page and one to the next, in the menu's order: what the default template's `<footer>` gets |

A component is outside the article: the editor does not see it, and it
is never written to a file. A file of yours with the same name, such as
`components/pager.jsx`, replaces minidoc's.

To write one of your own, put it in the `components/` folder, in a
`.jsx` file named after it. It needs no import and no `package.json`:

```jsx
// components/count.jsx
export default function Count({ pages }) {
  return <p>{pages.length} pages</p>;
}
```

```html
<footer data-component="count"></footer>
```

A component gets two props:

| Prop | What it holds |
| --- | --- |
| `page` | the current page: `title`, `href`, and `headings`, each with its `level`, `text` and `slug` |
| `pages` | every page, in the menu's order: `title` and `href` |

The component draws again when they change: a page added, a title
renamed, a heading typed. A component of the folder with the name of
one of minidoc's replaces it: `components/menu.jsx` draws the menu, in
`<nav>` too. A name that neither minidoc nor `components/` has is
refused, with the name, so a typo shows at once.

A heading's link is its slug, as on GitHub: `## A date you can set` is
`page.html#a-date-you-can-set`. Two headings with the same text take
`-1`, `-2` after the second and the third.

::: settled
**The template names its components; the folder holds them** 2026-11-14
Convention over configuration: a component is a file of `components/`,
and an element names it in `data-component`. No file maps them. The
template stays plain HTML, which a designer writes and opens in a
browser. minidoc reads it with the same DOM API on both sides:
`querySelector` in Node with `linkedom`, and in the browser with the
page's own document.

Rejected: a `site.mjs` that maps selectors to components. It is a file
of configuration, and a name in the template says the same thing where
the element is. Rejected: a component in ReScript for a site. A `.jsx`
file needs no compiler; minidoc's own components stay in ReScript.
Rejected: a React layout from the first level. A person who wants their
own style must then write a component, and learn the site's state, for
what an HTML file gives.

Cost: a component fills an element and cannot change the structure
around it. For that, a site writes a React layout, the last level.
:::

### The croquis

A croquis tries the levels before anything else is rebuilt. It is a new
core, in `packages/core/src2/`, with nothing of `src/`. `pnpm dev` at the
root runs it on `packages/core/croquis/`, a folder with one markdown
file. It starts at level 0, with no layout.

::: proposed
**The steps of the croquis**
1. `minidoc <folder>`: the pages of the folder, the default template,
   the menu, and the editor, served with editing off at build and on in
   the page.
2. A change in the page writes the file. A change of the file lands in
   the page through the socket, merged by `View.land`.
3. `index.html`: `<article>`, `<nav>` and `<title>` filled.
4. Images: an image line drawn, a paste or a drop written in the
   folder.
5. The map of selectors to components, with `Minidoc.Contents` as its
   first component of its own.
:::

::: settled
**Step 1 is built** 2026-11-13
`pnpm dev` at the root serves `packages/core/croquis/` at a port drawn
from the folder's path, so it keeps its address across restarts. The
fixture passes, and `node test2/chrome.mjs` checks in Chrome that the
page hydrates with no mismatch and no error, shows the blocks the server
drew, and turns editing on.

What step 1 showed:
- The editor's view with editing off is already close to plain HTML:
  `h1`, `p`, `ul`, `a`, `strong`. What remains is a `contenteditable`
  root, the block ids, and a zero-width space around an atom.
- A quote, a table and a `:::` block draw through live's rule, as on
  today's dev page. Live splits a drawing's HTML with a `<template>`, so
  the server needs a `document`: the croquis gives it one with
  `linkedom`, until live splits HTML without one.
- The server is JavaScript (`serve.mjs`, `cli.mjs`); the site, the
  islands and the client are ReScript.
- Behind maia, the pages are served under `MAIA_BASE`
  (`/serve/<project>/`), with the prefix left on each request. The
  links of a page are relative, so they stay under it. The Chrome check
  runs under such a base.
:::

The fixture of step 1, `packages/core/test2/folder.test.yaml`: a folder
in, what each page shows out.

```yaml
feature: A folder of markdown files
# For a person who points minidoc at a folder of markdown files, and wants
# to read and edit them with no config. Level 0 of the croquis: the default
# template, a menu of the pages, and the editor's view of the text.
#
# A target names each page that the folder gives, and what it shows:
# `title` is the document's title, `nav` the text of each link of the menu,
# with "(current)" after the current page, and `article` the text of each
# block that the editor draws. `carries` is the JSON that the page carries
# for its hydration: the files its render read, and the pages.
background:
  given: a folder
examples:
  - scenario: a markdown file is a page, with the default template and a menu
    source:
      a.md: |-
        # First

        Some text.
    target:
      a.html:
        title: First
        nav: [First (current)]
        article: [First, Some text.]

  - scenario: the pages are in the order of their file names, and each marks itself in the menu
    source:
      b.md: "# Second"
      a.md: "# First"
    target:
      a.html:
        title: First
        nav: [First (current), Second]
        article: [First]
      b.html:
        title: Second
        nav: [First, Second (current)]
        article: [Second]

  - scenario: a page with no heading takes the name of its file as its title
    source:
      notes.md: Some text.
    target:
      notes.html:
        title: notes
        nav: [notes (current)]
        article: [Some text.]

  - scenario: index.md is the home page, written to index.html
    source:
      index.md: "# Home"
      about.md: "# About"
    target:
      about.html:
        title: About
        nav: [About (current), Home]
        article: [About]
      index.html:
        title: Home
        nav: [About, Home (current)]
        article: [Home]

  - scenario: a page carries the files its render read, and the pages, as JSON
    source:
      a.md: "# First"
      b.md: "# Second"
    target:
      a.html:
        carries:
          files:
            a.md: { version: 1, text: "# First" }
          pages:
            - { href: a.html, title: First }
            - { href: b.html, title: Second }

  - scenario: a file that is not markdown is not a page
    source:
      a.md: "# First"
      notes.txt: Some text.
    target:
      a.html:
        nav: [First (current)]

  - scenario: a folder with no markdown file is refused
    source:
      notes.txt: Some text.
    error: "the folder holds no markdown file"
```

### Step 2: the sync

A key in the page writes the file. A save of the file by another program,
an agent or another page lands in the page, merged with what the person
typed, with no reload and the caret where it was. A renamed heading
changes the menu and the title of each open page.

::: proposed
**How the sync works in the croquis**
- **A pure `Sync` module** in `src2` holds each markdown file at a
  version, and the file each open page shows. It takes three events (a
  page opens a file, a page saves, a change on disk) and answers the
  messages to send. The fixture below runs it in memory.
- **`serve.mjs` wires it**: a WebSocket through `ws` at
  `./__minidoc/sync`, relative to the page, so it works under maia's
  base; and `fs.watch` on the folder for the changes on disk.
- **The page saves as live's dev page saves**: 300 ms after the last key,
  `Page.write` gives the text, and only the blocks the person changed
  differ. The save names the version it starts from.
- **A file that lands** is read with `Page.read`, its block ids kept from
  the last section with `Identity.read`, and given to `View.land`. The
  merge is the radif binding's: a block changed in the page keeps the
  page's text, and the next save carries it; every other block takes the
  file's. A refused save lands the same way, then saves again on the new
  version.
- **A `pages` message** sets the pages of the carved site, so tilia draws
  the menu again and the `observe` writes the title.
- **A closed socket** (`dev` restarted) reloads the page once the server
  answers again.

Rejected for now: a word merge of a block both sides changed
(`TiliaEditor.Merge`). Its cost: when the person and the disk change the
same block, the person's text wins.
:::

The fixture of the server's side, `packages/core/test2/sync.test.yaml`:

```yaml
feature: The sync of a folder with its open pages
# For a person who edits a page while other programs, agents or other
# pages change the same files. `dev` keeps each markdown file at a version,
# and each open page says the file it shows. A save names the version it
# starts from; a change on disk is sent to the pages that show the file.
#
# `files` is the folder at the start, each file at version 1. Each step is a
# page that opens a file (on the version it holds, 1 when not said), a page
# that saves, or a change on disk. `sent` is
# every message, in order: to the disk, to a page by its number, or to all
# the pages. A message to no page is not sent.
background:
  given: a sync
examples:
  - scenario: a save on the version that stands writes the file, answers the next version, and goes to the other pages of the file
    files:
      a.md: "# First"
    steps:
      - { page: 1, opens: a.md }
      - { page: 2, opens: a.md }
      - { page: 1, saves: a.md, on: 1, text: "# First\n\nMore." }
    sent:
      - { to: disk, writes: a.md, text: "# First\n\nMore." }
      - { to: 1, saved: a.md, version: 2 }
      - { to: 2, file: a.md, version: 2, text: "# First\n\nMore." }

  - scenario: a page that opens on an older version gets the file that stands
    files:
      a.md: "# First"
    steps:
      - { disk: a.md, text: "# First\n\nNew." }
      - { page: 1, opens: a.md, on: 1 }
      - { page: 2, opens: a.md, on: 2 }
    sent:
      - { to: 1, file: a.md, version: 2, text: "# First\n\nNew." }

  - scenario: a save on an older version is refused, with the file that stands
    files:
      a.md: "# First"
    steps:
      - { page: 1, opens: a.md }
      - { disk: a.md, text: "# First\n\nFrom disk." }
      - { page: 1, saves: a.md, on: 1, text: "# First\n\nFrom the page." }
    sent:
      - { to: 1, file: a.md, version: 2, text: "# First\n\nFrom disk." }
      - { to: 1, stale: a.md, version: 2, text: "# First\n\nFrom disk." }

  - scenario: a change on disk goes to each page that shows the file, and to no other
    files:
      a.md: "# First"
      b.md: "# Second"
    steps:
      - { page: 1, opens: a.md }
      - { page: 2, opens: b.md }
      - { disk: a.md, text: "# First\n\nNew." }
    sent:
      - { to: 1, file: a.md, version: 2, text: "# First\n\nNew." }

  - scenario: the server's own write, seen again by the watcher, sends nothing
    files:
      a.md: "# First"
    steps:
      - { page: 1, opens: a.md }
      - { page: 1, saves: a.md, on: 1, text: "# First\n\nMore." }
      - { disk: a.md, text: "# First\n\nMore." }
    sent:
      - { to: disk, writes: a.md, text: "# First\n\nMore." }
      - { to: 1, saved: a.md, version: 2 }

  - scenario: a new markdown file sends the pages to every page
    files:
      a.md: "# First"
    steps:
      - { page: 1, opens: a.md }
      - { disk: b.md, text: "# Second" }
    sent:
      - { to: all, pages: [First, Second] }

  - scenario: a changed first heading sends the pages, and a change elsewhere sends only the file
    files:
      a.md: "# First\n\nText."
    steps:
      - { page: 1, opens: a.md }
      - { page: 2, opens: a.md }
      - { page: 1, saves: a.md, on: 1, text: "# Renamed\n\nText." }
      - { page: 1, saves: a.md, on: 2, text: "# Renamed\n\nMore text." }
    sent:
      - { to: disk, writes: a.md, text: "# Renamed\n\nText." }
      - { to: 1, saved: a.md, version: 2 }
      - { to: 2, file: a.md, version: 2, text: "# Renamed\n\nText." }
      - { to: all, pages: [Renamed] }
      - { to: disk, writes: a.md, text: "# Renamed\n\nMore text." }
      - { to: 1, saved: a.md, version: 3 }
      - { to: 2, file: a.md, version: 3, text: "# Renamed\n\nMore text." }

  - scenario: a removed markdown file sends the pages, and the pages that showed it learn it is gone
    files:
      a.md: "# First"
      b.md: "# Second"
    steps:
      - { page: 1, opens: b.md }
      - { disk: b.md, removed: true }
    sent:
      - { to: 1, gone: b.md }
      - { to: all, pages: [First] }

  - scenario: a save of a file that is not a markdown file of the folder is refused
    files:
      a.md: "# First"
    steps:
      - { page: 1, opens: a.md }
      - { page: 1, saves: ../secret.md, on: 1, text: "x" }
    sent:
      - { to: 1, refused: ../secret.md, reason: "../secret.md is not a markdown file of the folder" }
```

Chrome checks the page's side, on a copy of the croquis folder:

1. A key in the page writes the file, and the other blocks keep their
   bytes.
2. A save of the file by another program changes the text in the page,
   with no reload, and the caret where it was.
3. A word typed in one block and a change on disk to another block both
   stay.
4. Two pages of the same file: a key in one shows in the other.
5. A renamed first heading changes the menu and the title of the page.

::: settled
**Step 2 is built** 2026-11-13
The 9 scenarios of the sync pass, and `node test2/chrome.mjs` checks the
5 above in Chrome, on a folder of its own in the system's temporary
folder. A ninth scenario came while building: a page that opens on an
older version, because the file changed between its render and its
socket, gets the file that stands.

What step 2 showed:
- The editor's own save keeps its row on each block-list change, saved
  or not. So the page keeps its own base for the merge: the last section
  that the server confirmed.
- `Identity.read` gives a block a new id when it keeps less than half of
  its words: `typed` and `typed,` are two words. When the person types in
  that same block meanwhile, the merge sees the person's block as gone,
  and the person's words are lost. A word merge of the block, or a
  likeness by characters for short blocks, would keep them.
:::

### Step 3: `index.html`

When the folder holds an `index.html`, it is the template of every page.
minidoc keeps it as it is written, and fills `<article>` with the page,
`<nav>` with the links, and `<title>` with the page's title.

::: proposed
**How the template works in the croquis**
- **The template is read from the folder**, and the default template is
  the same code with minidoc's own `index.html`. The template is never a
  page, and never served as a file.
- **Two stylesheets of minidoc go in every page, first in its head**:
  the blocks' (`blocks.css` and its theme), which draw a quote or a `:::`
  block, and a new `editor.css`, which holds only what the editor's
  elements need: no outline, the code block's language label, no line
  around a drawn block. The template's own stylesheets come after them,
  so they win. The sober style, `minidoc.css`, goes only in the default
  template.
- **A template with no `<article>` is refused**, since the page has no
  place in it. With no `<nav>`, the page has no menu. With no `<title>`,
  minidoc puts one in the head.
- **A change of `index.html` reloads the open pages**, each once its
  edits are saved. A template changes what is outside the islands, which
  a hydration cannot draw again. This replaces the croquis choice that
  the islands draw again with no reload.

Rejected: the template's example content kept as a pattern for the menu,
such as its first link repeated for each page. It can come with step 4.
:::

The new scenarios of `folder.test.yaml`: the default template's
stylesheets; `index.html` as the template, with the rest as written; no
`<nav>`; no `<title>`; no `<article>`, refused. Of `sync.test.yaml`: a
change of `index.html` reloads every page, and the same text again does
not; a new or removed `index.html` reloads them too.

A Chrome check: a word typed, then a change of `index.html` at once. The
page reloads with the new template, and the file holds the word.

::: settled
**Step 3 is built** 2026-11-13
The 5 new scenarios of the folder and the 2 of the sync pass, and the
Chrome check of the template passes with the 11 before it. Put an
`index.html` with an `<article>` in the folder, and each page takes it.

What step 3 showed:
- The editor's needs are few: `editor.css` is a dozen rules. The
  drawing of a quote or a `:::` block takes the article's leading back
  through one variable, `--minidoc-leading`, which a template may set.
- `index.html` itself is never served: a request for it goes to the
  first page.
:::

### Step 4: images

Today an image is lost: the editor reads `![a cat](cat.png)` as text, and
draws an `!` and a link. An image is a file of the folder, like a page,
and the page shows it, keeps it, and takes a new one from a paste or a
drop.

::: proposed
**How images work in the croquis**
- **The editor reads an image.** A line that holds only an image is an
  atom of the format `image`, whose value is its markdown, written back
  with the same bytes. An image inside a sentence is drawn as an `<img>`
  in its text. Both are changes to the editor's page reader and inline
  reader, in the editor's repo.
- **minidoc gives the `image` rule.** It draws an `<img>` whose `src` is
  relative to the page, as on GitHub and in any markdown editor, so the
  same file shows in the static page, in `dev`, and behind maia.
- **A paste or a drop of an image file** goes through the view's `paste`
  hook. The page names the file, draws it at once from the browser's own
  copy, and sends it to `dev`, which writes it in the folder. The atom
  is `![](name.png)`, saved with the page as any other block.
- **An image changed on disk** is drawn again in each page that shows
  it: the sync sends its new version, and the `src` takes it as a query,
  so the browser does not keep the old one.
:::

::: settled
**A pasted image goes in an `images/` folder, named after its page**
The person pastes into `notes.md`: `dev` writes `images/notes-1.png`, the
next number free, and the page holds `![](images/notes-1.png)`. The
pages stay apart from their images. `assets/` was the other name; a PDF
or a video can make it the better one later.

Rejected: the image beside its page, which mixes the two in the menu's
folder. Rejected: a name from the content's hash, which says nothing to
the person who reads the folder.

Cost: `images/` is the first sub-folder that the sync and the watcher
read.
:::

::: note
**What the editor gives an image**
`TiliaEditor.Image.rule(~image, ~hold, ~replace)` draws an image atom
from a row: loading, uploading with its progress, downloading, missing,
or ready. Its pane holds the placement (float and width) and a
"Replace…" button. It has no name to change. A rule's `view.pane` can be
replaced, and a pane changes the atom with `onChange({value, placement,
uses})`. So minidoc keeps the editor's drawing and gives an image a pane
of its own: the file's name and the alternative text.
:::

::: settled
**A rename moves the file, and rewrites every link to it in the folder**
The person renames `images/notes-1.png` to `images/diagram.png` in the
image's pane. `dev` moves the file, then rewrites each markdown file of
the folder that links the old path. The pages that show those files take
them through the sync, as any change on disk. A rename never breaks a
link.

Rejected: a rename only when the page is the image's one link, which
leaves the other links to the person. Rejected: a rename that copies the
file, which fills the folder with copies.

Cost: a rename writes every page that links the image, in one go.
:::

::: settled
**This session changes the editor's readers, with their scenarios**
The page reader makes a line that holds only an image an atom of the
format `image`, written back with the same bytes; the inline reader draws
an image inside a sentence as an `<img>`. The scenarios go first in the
editor's own fixtures, then the build, then the editor's checks. Nothing
else of the editor's open work is touched, and its session gets a
handoff.

Rejected: a handoff to the editor's session, as the copied table's
header was. The croquis would wait for it.
:::

::: settled
**A pasted image has an empty text, and its pane opens on the text field**
`![](images/notes-1.png)`. The image's pane opens at once after the
paste, its focus on the text field: the person describes the image in
one go, or presses Escape. A screen reader says "image", not a file
name.

Rejected: the name of the pasted file, which says nothing of the image.
Rejected: a text that a model writes, a call to a service at each paste.
:::

::: proposed
**An image inside a sentence waits; step 4 is the image on its own line**
The fixture keeps `See ![a cat](cat.png) here.` as text, as the editor
reads it today. To draw it, the page writer must write an atom inside a
line of prose back with the same bytes, which it does not do yet. That
is a later step of the editor, recorded in the plan.
:::

The fixtures of step 4:

- **The editor's `Page.yaml`**, 7 new scenarios: a line that holds only
  an image is an `image` atom, with its title, with no text, between
  paragraphs; an image inside a sentence stays text, and so does an
  image with a line of text under it; an image's new text is written on
  its line, and the rest keeps its bytes.
- **`folder.test.yaml`**, 2 new scenarios: an image line is drawn as an
  `<img>` relative to the page; the folder's images go with the pages in
  what the page carries.
- **`sync.test.yaml`**, 7 new scenarios: a page stores a pasted image
  under the name it asks; a name already taken takes the next one free;
  an image is stored only in `images/`, and only as an image; a rename
  moves the image and rewrites every page that links it; a rename to a
  taken name is refused; an image changed on disk goes to every page at
  its next version; a removed image leaves the images.

Chrome checks the page:

1. An image line shows the image, served and hydrated.
2. A pasted image shows at once, is written to `images/a-1.png`, and its
   pane opens on the text field; the text typed there is written in the
   file.
3. A rename in the pane moves the file, rewrites another page that links
   it, and the image still shows.
4. An image changed on disk is drawn again.

::: proposed
**The steps of step 4**
1. The editor: the page reader and writer of an image line, with their
   scenarios, then the editor's checks.
2. The site: the folder's images, read with the pages and carried by
   each page.
3. The sync: an image stored from a page (its bytes in base64 over the
   socket), a rename that moves the file and rewrites its links, and
   the version of each image; `serve.mjs` writes, moves, and watches
   `images/`.
4. The page: `TiliaEditor.Image.rule` draws the image, ready from its
   file, or uploading from the browser's own copy until `dev` stores
   it; minidoc's pane holds the name and the text; the `paste` hook
   names the file `images/<page>-<n>.<ext>`.
:::

::: settled
**Step 4 is built** 2026-11-14
The 7 scenarios of the editor's `Page.yaml`, the 2 of the folder and the
7 of the sync pass. `node test2/chrome.mjs` checks the 4 above in Chrome,
with the 12 before them. The editor's suite has no new failure, and 5
of its failures before now pass.

What step 4 showed:
- `TiliaEditor.Image.rule` reads an image from a row of the atom's
  `uses`, not from its markdown. So minidoc draws its own `<img>` and its
  own pane, in `Picture.res`, and does not keep the editor's drawing.
- The editor drops a pasted atom's pane. The page selects the pasted
  image just after the paste, so its pane opens on the text field.
- The editor refuses a drop (`insertFromDrop`). Step 4 takes a paste
  only, and a drop waits in the plan.
- The page editor of today's `dev`, `@minidoc/live/edit`, reads an image
  line as an `image` atom too. It draws it as an `<img>`, with no pane.
  A fixture and a Chrome check of `pnpm docs:edit-check` cover it.
:::

### Step 5: components

Level 2, as taught above: an element of `index.html` names a component
in `data-component`, minidoc gives `contents` and `menu`, and the
folder's `components/` holds the site's own, in `.jsx`.

::: settled
**The contents read the editor's headings, and link to their slugs** 2026-11-14
The page publishes its headings, from the editor's document, at each
change: the level, the text and the slug of each. `contents` draws them.
At the render, they come from the same reading as the page, so the
hydration has no mismatch. A heading's slug is its text, as on GitHub:
the links of tilia's and radif's websites are slugs today.

The editor draws a heading with its block id, which it needs. So the
page leads a link to a slug to its heading: a click on it, or a page
opened with it.

Rejected: the contents read the file's text again. A block that the
person adds takes an id from the editor, and a new reading gives it
another one. Rejected: a link to the block id. It changes with the text,
and no other site can link to it.

Cost: the static HTML of the build, a later step, must give each
heading its slug as its id.
:::

::: technical
**How the croquis builds components**
- The server finds `[data-component]` and `<nav>` with linkedom, and
  draws each with `renderToString`. The client hydrates each element as
  its own React root.
- esbuild builds `components/*.jsx` twice: for Node, to draw the pages,
  and for the page. `react` resolves to minidoc's own copy, and the JSX
  needs no import. A change of a file of `components/` builds them again
  and reloads the open pages, once their edits are saved.
- minidoc hands each component plain values, and draws it again when
  they change. A component of the site learns no hook.
- `contents` and `menu` are ReScript, in minidoc.
:::

The fixtures of step 5:

- **`folder.test.yaml`**, 6 new scenarios. A scenario gives the folder's
  files: `index.html`, the pages, and `components/*.jsx`.
  1. `data-component="contents"` shows the `##` and `###` headings, a
     `###` in a list under its `##`, each linked to its slug.
  2. Two headings with one text take `-1` after the second.
  3. A component of the folder draws in each element that names it, and
     keeps the element's attributes.
  4. `components/menu.jsx` replaces the menu in `<nav>`.
  5. A name that no component has is refused, with the name.
  6. A page carries its headings for its hydration.
- **`sync.test.yaml`**, 1 new scenario: a change of a file of
  `components/` reloads every page.

Chrome checks the page, on a folder with an `index.html` that holds
`<aside data-component="contents">` and `<footer
data-component="count">`, and `components/count.jsx`:

1. The contents and the count show, hydrated with no error.
2. A heading typed in the page shows in the contents at once, and a
   click on its link leads to it.
3. A new file on disk changes the count.
4. A change of `components/count.jsx` reloads the page with the new
   component.

::: proposed
**The steps of step 5**
1. The render: each element that names a component, `<nav>` as `menu`,
   and the page's headings with their slugs.
2. `contents`, and the slugs.
3. The page publishes its headings at each change, and leads a link to
   a slug to its heading.
4. `serve.mjs` builds `components/` for Node and for the page, and
   builds it again on a change.
:::

::: settled
**Step 5 is built** 2026-11-14
The 6 new scenarios of the folder and the 1 of the sync pass, and
`node test2/chrome.mjs` checks the 4 above in Chrome, with the 16 before
them. Put `<aside data-component="contents"></aside>` in `index.html`,
and the page shows its contents.

What step 5 showed:
- A component gets plain values, and minidoc draws it again when they
  change. So a component of the site needs no tilia and no hook, and
  `leaf` is not needed.
- A component that does not build keeps the last good build, and each
  page shows the error until it builds.
- The callouts that the editor draws took their space from three
  places: the theme's padding, the label's own line, and the page's
  margin after each paragraph. Now the label is a small word at the top
  right, the text flows around it, and an empty byline takes a line only
  while the caret is in its callout. A fifth Chrome check holds it.
:::

### What tilia's and radif's websites need

Step 5 ends level 2: a folder of notes, with a template and parts of its
own. tilia's and radif's websites need much more. This is what each one
uses today, and where the croquis stands.

| A site uses | tilia | radif | The croquis after step 5 | The design |
| --- | --- | --- | --- | --- |
| A page made of several files: the guide's chapters, the API's entries | yes | yes | no: one file is one page | [Sections](#a-page) |
| Frontmatter: a slug, a menu label, a menu, `archived`, the API's fields | yes | yes | no | [The site](#site) |
| Sub-folders: `guide/`, `api/objects/`, `brief/`, `pages/` | yes | yes | no: one flat folder | [The site](#site) |
| A link to a heading or a section by its slug: `api.html#make` (201 in tilia) | yes | yes | no: block ids | [The site](#site), for sections |
| A template for each kind of page: home, guide, API | yes | yes | no: one `index.html` | [The site](#site) |
| A menu of its own: a package switcher, the brief and the working menus | yes | yes | yes, with a component in `nav` | step 5 |
| Pages from data: `ROOT-TYPES.yaml`, the count of scenarios | no | yes | no | [Pipelines](#files), [Derived](#derived) |
| Blocks of its own: radif's drawings, KaTeX | no | yes | no | [Derived](#derived) |
| Code in colours, and tilia's TypeScript and ReScript pair | yes | yes | no | not designed |
| A static build to a folder, with plain HTML | yes | yes | no: `dev` only | [The open questions](#open) |
| Outputs that are not HTML: redirects, `llms.txt` | yes | no | no | [The site](#site), partly |

::: proposed
**After step 5, the croquis takes the steps that tilia needs, then radif's**
tilia's website is the smaller one, with no data pipeline. So it goes
first.

6. Sections and frontmatter: a page made of several files, its
   sub-folders, and a slug for each section and each heading, as the
   links of both sites use today.
7. A template for each kind of page, named by the frontmatter.
8. Code in colours, and a pair of code blocks shown one at a time.
9. The build: plain HTML in an output folder, redirects and `llms.txt`.
   Then tilia's website moves.
10. Pipelines for YAML and for files outside the folder, and the site's
    own blocks. Then radif's website moves.

Rejected: tilia's website on the croquis after step 5. It has neither
sections, slugs, frontmatter nor a build.

Cost: five more steps before a real site moves.
:::

### Step 6: a page of several files

tilia's Guide is one page. Its head is `guide.md`, and its thirteen
chapters are the files of `guide/`. Each chapter is edited on its own,
and the page reads them in order, as one story. The API is one page too,
with one file for each entry. Step 6 gives a folder three things: a page
made of several files, the frontmatter in the template, and callouts of
the site's own.

#### A page names its sections

```markdown
---
sections: guide/*.md
nav: Guide
eyebrow: Guide · v6.x
---
# The Guide

A reading path through tilia, in order.
```

```markdown
## A living object

Everything in tilia starts with two moves.

::: story
Claudine's first task is the first scenario.
:::
```

You get:

- `guide.md` is the page `guide.html`. Its own text comes first, then
  each section, in the order of the file names.
- `guide/03-a-living-object.md` is a section, not a page. It has no
  HTML file and no place in the menu.
- The section's slug is its file name without the number:
  `a-living-object`. `guide.html#a-living-object` leads to it.
- The section's title is its first heading. You edit it in place, as any
  other text. The contents follow it after the editor's pause.
- `sections` takes one glob or a list of them. The API lists its groups
  in turn: `[api/objects/*.md, api/effects/*.md]`.
- A markdown file in a sub-folder that no page names is a page of its
  own. `notes/today.md` is `notes/today.html`, and its links and
  stylesheets are relative to it.

::: settled
**The file name gives a section its slug and its place** 2026-11-16
`01-drawn-before-built.md` is the first section, and its slug is
`drawn-before-built`. A `slug` or a `sort` in the frontmatter changes
nothing. A file name is the one place for both: a link stays when the
title changes, and the order shows in any file list.

Rejected: `slug` and `sort` in the frontmatter, as in today's
`config.yaml`. They repeat the file name, and the two can disagree.

Cost: tilia's 94 files lose `slug` and `sort`. Each of their slugs is
already the file name without its number.
:::

::: settled
**A section is drawn in its own element, and its title heading takes no slug** 2026-11-16
Each section is a `<section id="a-living-object">` in `<article>`, after
the page's own text. Its first heading takes no slug of its own, so the
page has one id for it. `contents` links that heading to the section.
The other headings take their slugs as before, unique over the whole
page.

Rejected: one heading id and no element. A section needs an element
anyway, because each file is its own editor.
:::

::: settled
**Each section is its own editor, and saves to its own file** 2026-11-16
The page opens each of its files: the head and every section. A key
typed in a section changes that section's file, and nothing else. A
new block at the end of a section stays in that section. A new section
is a new file. A file that appears on disk and matches the glob becomes
a section of every open page that names it, at once.

Rejected: one editor over the whole page, which splits its blocks into
files on save. The editor has no such engine, and a block on the border
of two files has no clear home.

Cost: the caret does not cross from one section to the next with the
arrow keys, until the editor gives a way to do it.
:::

#### The frontmatter in the template

An element of `index.html` with `data-front` shows the value of that
key of the page's frontmatter:

```html
<p class="eyebrow" data-front="eyebrow"></p>
<p class="lead" data-front="lead">A page with no lead shows this.</p>
```

- A text, a number, a date or a yes or no shows as written.
- When the page has no such key, the element keeps what you wrote.
- A list or a map shows nothing. A component reads it.
- A key is read whole: `signature.ts` is one key.

A component gets the frontmatter too. `page.front` is the page's,
`page.sections` gives each section its `slug`, `title`, `nav`, `file`
and `front`, and each page of `pages` has its `front`:

```jsx
export default function Entries({ page }) {
  return (
    <ul>
      {page.sections.map((s) => (
        <li key={s.slug}><a href={`#${s.slug}`}>{s.front.label}</a></li>
      ))}
    </ul>
  );
}
```

`nav` in a page's frontmatter names the page in the menu. Without it,
the menu shows the title.

::: settled
**The page does not show its frontmatter as fields, in step 6** 2026-11-16
The frontmatter stays a text of the file. A value changed on disk, by
you or an agent, lands through the sync, and each element and component
that reads it draws again. The editor's `FrontFields` can come later,
as a panel.

Rejected for step 6: the fields above the text. tilia's API entries
have ten keys each, and ten inputs over each entry make the page a form.
:::

#### Callouts of the site's own

tilia writes `::: story`, `::: pro` and `::: def`. A site names its own
callouts in `index.html`, one `<meta>` each, the name first and then the
label:

```html
<meta name="callout" content="story Story">
<meta name="callout" content="pro Pro tip">
<meta name="callout" content="def Definition">
```

The editor draws them as it draws `note` or `settled`: a callout of the
kind, with its label, which you edit in place. Its class is
`callout--pro`, so the site's stylesheet gives it its look. A name that
is already a block of minidoc, such as `states`, is refused.

::: settled
**A site names its callouts in its template** 2026-11-16
The template is the one file that each page of the site shares, and its
stylesheet styles the callouts. A `<meta>` is plain HTML, and the
template's author already writes the head.

Rejected: a key in the head page's frontmatter. Each page would repeat
it. Rejected: a `callouts/` folder. A label is one word, not a file.
Rejected: a config file. The croquis has none, by design.

Cost: a folder with no `index.html` has only the common callouts.
:::

The fixtures of step 6:

- **`sections.test.yaml`**, a folder in the shape of tilia's guide and
  API: the sections in order, their slugs, a list of globs, a page in a
  sub-folder, the contents, what the page carries, `data-front`, a
  component that reads the frontmatter, `nav`, the callouts, and the
  refusals.
- **`sections-sync.test.yaml`**: a section file is not a page, a save of
  a section writes its file, a new heading or a new file sends the
  pages with their sections.

Chrome checks, on a copy of tilia's guide:

1. The page shows its head, then each chapter in order, hydrated with
   no error.
2. A word typed in a chapter is saved to that chapter's file only.
3. A chapter's heading typed anew changes the contents.
4. A new chapter file on disk shows in place, in its order.
5. A word typed in a `::: pro` callout is saved, and the callout keeps
   its kind.
6. `guide.html#a-living-object` opens at the chapter.

::: settled
**Step 6 is built** 2026-11-16
The 19 scenarios of `sections.test.yaml` and the 6 of
`sections-sync.test.yaml` pass, and `node test2/chrome.mjs` checks the 6
above in Chrome, on a copy of the twelve chapters of tilia's guide. Put
`sections: guide/*.md` in the frontmatter of `guide.md`, and the page
shows each chapter.

Three things came while building:

- Each section's editor puts the section's slug before the ids of its
  blocks, so two files of a page never share an id.
- A folder that is refused while `dev` runs, such as a file that two
  pages name, shows its reason in place of each page, and the open pages
  keep what they show.
- An edited block takes the editor's spelling, `_word_` for `*word*`.
  Each other block of the file keeps its bytes.

Not done: an element with `data-front` whose key leaves the frontmatter
keeps the last value until the page loads again.

Before tilia's website moves, each of its chapters takes its title as
its first heading. Today the title is in the frontmatter.
:::

### A changelog

A project shows that it is alive: the date and the version of its last
release on the home page, and its changes on a page of their own. The
format of `CHANGELOG.md`, and the `release` and `changelog` components
that read it, are on [the blocks' Changelog page](./blocks.html#changelog).
They come after step 6.

::: technical
**Choices of the croquis**
- ReScript, compiled to `.mjs`, as the rest of minidoc.
- The socket is a WebSocket through `ws`, on the server that serves the
  pages. Rejected: the server-sent events and the `POST` of today's
  `dev`. They are two channels, and a save's version and its answer are
  easier on one.
- The default template is an HTML file and a stylesheet in `src2`. It is
  level 1 with minidoc's own `index.html`, so level 0 and level 1 are the
  same code.
- No `config.yaml`, no var, no transform.
:::
