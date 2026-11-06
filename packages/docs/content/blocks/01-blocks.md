---
slug: blocks
nav: The package
title: The package
fixture: ""
---
`@minidoc/blocks` gives every minidoc site the same `:::` blocks:
callouts, quotes, flows, plans, screen mockups, sequences, state machines
and database models. A site passes one transform to `run`, and its pages can use
them all.

```sh
pnpm add -D @minidoc/blocks
```

```js
import { run } from "@minidoc/core"
import { blocks } from "@minidoc/blocks"

await run({ glob: "content/config.yaml", transform: { md: blocks({}) } })
```

The site copies `blocks.css` and one theme from the package, and sets the
theme on its `html` element: `<html data-blocks-theme="soft">`.

A drawing can open full screen. The site copies `viewer.js` from the package
too, and loads it once in its layout:

```html
<script src="./viewer.js" defer></script>
```

A click on a sequence, a state machine or a database model then shows it
full screen. ‹ and › or the arrow keys step through every drawing of the
page. A click on the drawing, or Escape, closes it. `data-select` on the
script tag names other blocks to open, as a CSS selector:
`data-select=".states, .model, .chart"`. The viewer brings its own styles,
in the colours of the blocks theme.

Each plate below is a scenario of the package. The **markdown** is what an
author writes. The **nodes** are what the package reads in it: a middle
language between the markdown and the HTML, which a live editor can redraw
one block at a time. The **page** is what a reader sees. The switch at the
top of this page changes the theme of every page drawn here, and nothing
else.

The plates are built from the fixtures in `blocks/test/` when the site is
built. A plate whose nodes are not the ones its fixture expects says so.
