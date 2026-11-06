---
slug: contracts
nav: Contracts
title: The HTML contract
fixture: ""
---
The nodes are drawn into HTML whose class names the stylesheet and the
themes rely on. That HTML is held by its own fixture,
`blocks/test/html.test.yaml`, one scenario for each kind of node. The page
around the blocks, with its anchors, its highlighted code and its wrapped
tables, is held by `blocks/test/page.test.yaml`.

Each block is drawn once, as a tree of elements, text, prose and fields.
`draw` gives the tree, and `render` writes it as HTML. `@minidoc/live`
writes the same tree as React elements, and runs the same HTML contract:
each of its scenarios must give the same DOM when drawn live.

A field is a value a person may edit in place: a plan's todo, a flow's
step, a screen field's value, an API call's path. Its key names its place,
counting from 1, such as `column 1 step 2` or `widget 3 value`, and its
value is its source text. A static page writes a field as its text.
`blocks/test/fields.test.yaml` lists the fields of a plan, a flow, a
screen and an API call.

A theme sets variables and nothing else. Every colour comes from a
`--tone-*` variable, and a block mixes its fill and its edge from it.
Shapes are variables too: radii, padding, the label's case and spacing,
the quote's rule, the screen's width and shadow, and the gaps of a flow.
