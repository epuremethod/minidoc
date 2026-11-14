---
slug: open
nav: Open questions
title: Open questions
---
::: settled
**Core takes React and the editor; live only mounts**
`@minidoc/core` holds `Minidoc.make` and `render(page, {live})`. It draws
the editor's view to HTML with `react-dom/server`, so a static site and a
live site use the same package and the same render. `@minidoc/live` keeps
only the script that mounts the editor on that HTML, and its end of the
sync.

Rejected: the render in `@minidoc/live` only, with core kept for the
filesystem and `dev`. Core would then render nothing, and a static site
would need live anyway.

Cost: a site that only builds pages installs React and the editor. Today
it installs neither.
:::

::: settled
**A change lands through a local sync, never through a rebuild**
`dev` keeps the mapping of the files to their sections, and a socket to
each page. A change from either side is a section that lands, merged by
the editor's three-way merge.

Rejected: a rebuild, then the new drawing taken from the rebuilt page.
It ties the page to the build's timing and to a refresh of the editor.

Cost: a site's pipeline and draws run in the `dev` process, not in a new
process for each build.
:::

::: settled
**A change of code restarts `dev`; a change of the template lands**
`pnpm dev` runs the croquis under `node --watch`. A change to `src2`
restarts it. Each page's socket closes and opens again, and the page
reloads, since its code changed too. `index.html` is a file of the
folder: a change to it comes through the sync, with no restart, and
reloads the open pages once their edits are saved (step 3).

Rejected: an import of the changed module again, with a new query
string. The modules it imports stay old, so a change two modules away
is not seen. Rejected: a new process for each change, as today's
builds. The sync keeps its versions and its sockets in the `dev`
process.

Cost: a change of code reloads the open pages.
:::

::: settled
**A new read of a file keeps its block ids, through `Identity.read`**
The editor already reads a text with no ids against the last section. A
diff of whole lines matches equal blocks first; the others pair by the
words they share. Each block that did not change keeps its id, and the
merge works block by block. Its cost is the editor's: a block that keeps
less than half of its words takes a new id.
:::

::: settled
**A page names its section files in its frontmatter, with a glob**
The page's own file is its head: the title and the lead. `sections`
names the files after it, in order, and each file is a section that is
edited on its own. See [A page](#a-page).

Rejected: a page of one file only. The Guide would become one long file,
or thirteen pages that lose the one story read in order.
:::

::: settled
**An image is a file with its own pipeline**
The image pipeline maps an image file to a row of the port. In a page,
`![alt](src)` is an image atom, and its use `src` names that row, as an
image atom of the editor names its row. The editor's image rule draws
the row's bytes as far as the storage has brought them, with an upload
and a download. `src` resolves against the page's file. The build writes
each image a page uses to the output. An image pasted in the page goes
up through the sync, and `dev` writes its file beside the page.

The page reader must still make the atom and its use from `![alt](src)`,
and write them back with the same bytes.
:::

::: settled
**A page carries the files its render read, as JSON**
The build records each file that a page's render read, and writes them
in the page, in a `<script type="application/json">`. In the croquis,
that is the page's markdown and the list of the pages with their
titles. The page's state starts from them, so the first render in the
browser has the values of the build, and hydrates with no blink. Then
the socket sends each change.

Rejected: a page that waits for the socket. The editor would replace the
HTML, which is the blink again, and a page with no `dev` would have no
editor. Rejected: a fetch of the files before the hydration, one request
more for each page.

Cost: each page carries the text of its files twice, as HTML and as
JSON.
:::

::: settled
**The croquis writes the editor's view as it is, with editing off**
`react-dom/server` draws `View.make` as it stands, and the page hydrates
it. The default style targets the editor's own elements. The croquis
shows what is wrong with that HTML, and the editor fixes it afterward:
the zero-width spaces around an atom, the ids on each block, and the
`contenteditable` root. Level 1 needs plain HTML, so the fix comes
before it.

Rejected for now: a reading mode in `@tilia/editor` before the croquis
starts. Rejected: the blocks' markdown renderer for the static HTML,
which is the two renders again.

Cost: the croquis's static pages carry the editor's marks. It is a
croquis choice, and it can change.
:::

::: settled
**Islands: one React root for each element of the map**
`article` and `nav` are each a React root, and all the roots read the
same carved site. The `<title>` is not a root: a tilia `observe` writes
`document.title`. The map of selectors works from level 0 on, so the
croquis tries it at once. A browser extension that writes elsewhere in
the page breaks nothing.

Rejected: a hydration of the whole document, from `<html>`. An
extension in the page breaks it, and an `index.html` of level 1 would
have to be a component. Rejected: one root in the body with portals to
the islands. React does not hydrate a portal from server HTML.

Cost: a part that is not in an island, such as the `<title>`, needs its
own `observe`.
:::

::: open
**Two-way pipelines for YAML**
A markdown file writes back with the same bytes, because the page reader
keeps each block's lines. A YAML fixture has no such reader yet, and a
write would move its comments and its layout. A YAML pipeline can be
read-only at first.
:::

::: proposed
**The way there**
1. A spike on this page: the editor draws it to clean HTML at build, and
   hydrates it in `dev` with no blink, images included. It answers the
   three questions above before anything else is built.
2. The editor's page reader makes image atoms, and the view draws to
   HTML with editing off.
3. `Minidoc.make`, the pipelines, and `render(page, {live})`, with a
   layout function.
4. The local sync: the socket, versions, and the merge at arrival.
5. Site blocks, with the files their draw reads.
6. These docs move to it, and the guide gets its new story.
7. radif, gdos, maia and the vs projects move to it.
8. Then the `@minidoc` release.
:::
