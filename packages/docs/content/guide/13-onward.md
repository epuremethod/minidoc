---
title: Onward
slug: onward
desc: Where to go next — the API reference, the blocks package, and the
  épure method minidoc belongs to.
refs: []
---

Mara's site has a guide, a reference, how-to pages and examples. Its config
is about a hundred lines, and most of them are her own HTML.

### Look things up

The [API reference](./api.html) has one entry for each function, config
key, var kind and rule, with every field. Read this guide once; use the
reference after that.

### Blocks

[`@minidoc/blocks`](./blocks.html) adds the `:::` blocks this guide
uses — callouts like the story boxes, quotes, flows, screen mockups,
sequences and state machines — as one markdown transform.

### For agents

The site publishes [`llms.txt`](./llms.txt) and
[`llms-full.txt`](./llms-full.txt), built from the same files as these
pages. The npm package ships them too, under `dist/`.

### épure

minidoc is part of [épure](https://epuremethod.com), a way of building
software where the drawing comes before the build. Its state layer,
[tilia](https://tiliajs.dev), is what makes minidoc's contexts lazy, and
its documentation is built with minidoc too.

::: story
A week later, the issue tracker is quieter. The answers are where people
look for them.
:::
