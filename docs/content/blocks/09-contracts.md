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

A theme sets variables and nothing else. Every colour comes from a
`--tone-*` variable, and a block mixes its fill and its edge from it.
Shapes are variables too: radii, padding, the label's case and spacing,
the quote's rule, the screen's width and shadow, and the gaps of a flow.
