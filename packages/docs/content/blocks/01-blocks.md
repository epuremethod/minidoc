---
slug: blocks
nav: The package
title: The package
fixture: ""
---
`@epure/minidoc-blocks` gives every minidoc site the same `:::` blocks:
callouts, quotes, flows, screen mockups, sequences and state machines. A
site passes one transform to `run`, and its pages can use them all.

```sh
pnpm add -D @epure/minidoc-blocks
```

```js
import { run } from "@epure/minidoc"
import { blocks } from "@epure/minidoc-blocks"

await run({ glob: "content/config.yaml", transform: { md: blocks({}) } })
```

The site copies `blocks.css` and one theme from the package, and sets the
theme on its `html` element: `<html data-blocks-theme="soft">`.

Each plate below is a scenario of the package. The **markdown** is what an
author writes. The **nodes** are what the package reads in it: a middle
language between the markdown and the HTML, which a live editor can redraw
one block at a time. The **page** is what a reader sees. The switch at the
top of this page changes the theme of every page drawn here, and nothing
else.

The plates are built from the fixtures in `blocks/test/` when the site is
built. A plate whose nodes are not the ones its fixture expects says so.
