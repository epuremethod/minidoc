---
slug: one-editor
nav: One editor
title: The editor renders every page
---
The editor becomes the only render. A static page is the editor's view,
drawn once to HTML with editing off. A live page is the same view with
editing on. The two have the same elements and the same classes, so the
switch from static to live changes nothing on the screen.

minidoc is then a thin wrapper around the editor. It stays in ReScript,
as today: `Minidoc.res` and `Dev.res` compile to `.mjs`, with
`Minidoc.resi` and a hand-written `index.d.ts`. The examples on this
page are a site's own code, in ReScript first, then in JavaScript. A
site can be written in either. `Site.editor` is made in
[The state](#state).

The wrapper does four things:

1. Define a layout.
2. Write the pages: markdown with frontmatter.
3. Make the editor: `let editor = Minidoc.make(config, Vars.carve)`.
4. Render each page: `editor->Minidoc.render(page, ~live)`.

```rescript
// Build.res: the static site, and the live one
let editor = Site.editor

// Each page with render(page, ~live=false), written to the output.
await editor->Minidoc.build

// Or, in dev, each page with render(page, ~live=true), and the sync.
await editor->Minidoc.dev
```

```js
// build.mjs
import { editor } from "./Site.mjs"

await editor.build() // or editor.dev()
```

In `dev`, `live: true` writes the same HTML and adds one script. The
script mounts the editor on the HTML that is there. It hydrates the
elements; it does not replace them. Then the page and `dev` stay in sync
through a small local socket: see [The local sync](#sync).

::: flow
1. **Build**
   1. Read the markdown and its frontmatter
   2. Draw the editor's view to HTML
      - editing off
   3. Put the layout around it
2. **Dev**
   1. Write the same HTML
   2. Mount the editor on it
      - editing on
   3. Sync each change with the files
:::
