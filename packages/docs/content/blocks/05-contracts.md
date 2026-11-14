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

A plan can be edited where it stands. Its marks are fields too, such as
`stage 2 mark` or `stage 2 todo 1 mark`, and its drawing names what a
click or a key does: tick a todo, move a stage along, add or remove a
todo or a stage. `edit` applies one of these to the block's source, and
changes only the characters it touches. `blocks/test/edits.test.yaml`
holds these edits, and `@minidoc/live` draws the plan with its inputs.

A theme sets variables and nothing else. Every colour comes from a
`--tone-*` variable, and a block mixes its fill and its edge from it. A
drawing's `color` picks from the palette, `--hue-grey`, `--hue-red`,
`--hue-orange`, `--hue-yellow`, `--hue-green`, `--hue-teal`, `--hue-blue`
and `--hue-purple`, which each theme gives.
Shapes are variables too: radii, padding, the label's case and spacing,
the quote's rule, the screen's width and shadow, and the gaps of a flow.

A theme sets each variable below, under `[data-blocks-theme="<name>"]`. A
site that writes its own theme starts from a copy of
`@minidoc/blocks/themes/soft.css`, which sets them all.
`blocks/test/themes.test.yaml` checks that each theme sets every variable
the stylesheets read, and that this list and llms.txt name each one.

::: settled
**The blocks follow the page's colour scheme** 2026-11-14
Each theme gives each colour twice, with `light-dark()`:
`--blocks-ink: light-dark(#202a38, #dcdfe4)`. The browser picks one from
the page's `color-scheme`. A page that declares `color-scheme: light
dark` gets dark blocks when the system is dark. A page that declares no
scheme, or `light`, keeps the light colours. gdos, radif and the vs
projects declare none or `light`, so nothing changes for them.

```css
:root { color-scheme: light dark; }
```

The variables stay the same, and a theme still sets variables only. In
soft, the dark colours keep each tone's hue, lighter, on a surface of
`#1f2024`. In graphic, black and white change places, and the red is
lighter. Each text of a callout, a plan and a drawing reaches a contrast
of 4.5 to 1 in both schemes. `blocks/test/schemes.test.yaml` checks that
each colour of each theme has its two values.

Rejected: `@media (prefers-color-scheme: dark)` in the themes. A site
with a light page only would get dark blocks on it at night. Rejected: a
dark theme of its own, `soft-dark`. The site must then switch the
attribute itself, with a script.

Cost: `light-dark()` needs a browser of 2024 or later: Chrome 123,
Safari 17.5, Firefox 120.
:::

| Variable | What it gives |
| --- | --- |
| `--blocks-ink` | the text, and the base a coloured text mixes toward |
| `--blocks-muted` | a secondary text: a type, a value, a label, a caption |
| `--blocks-line` | a thin rule: a border, a table's cell |
| `--blocks-stroke` | a drawing's lines and arrowheads |
| `--blocks-surface` | the ground of a block, and the base a fill or an edge mixes toward |
| `--blocks-canvas` | the ground of a flow of screens and of an API value |
| `--blocks-band`, `--blocks-band-ink` | the band over a flow of screens or an API call, and its text |
| `--tone-note`, `--tone-draft`, `--tone-proposed`, `--tone-settled`, `--tone-open`, `--tone-technical`, `--tone-principle`, `--tone-rejected`, `--tone-comment` | the colour of each kind of callout |
| `--tone-flow` | a flow's title and arrows |
| `--tone-done`, `--tone-doing` | a plan's stage done, and in progress, or an active step |
| `--tone-quote` | a quote's rule |
| `--tone-mark`, `--mark-ink` | a marked phrase, an open callout's label, and their text |
| `--tone-refused` | a refused message and an API error |
| `--tone-ui-primary`, `--tone-ui-clicked` | a screen's primary button, and the outline of a clicked one |
| `--hue-grey`, `--hue-red`, `--hue-orange`, `--hue-yellow`, `--hue-green`, `--hue-teal`, `--hue-blue`, `--hue-purple` | the palette a drawing's `color` picks from |
| `--fill-amount`, `--edge-amount` | how much of its tone a block's fill and edge take |
| `--label-fill-amount`, `--label-edge-amount`, `--label-ink-amount`, `--label-base` | a callout label's fill, edge and text, and the ground it mixes on |
| `--drawing-fill-amount`, `--drawing-edge-amount` | how much of its hue a drawn box's fill, and a drawn edge or line, take |
| `--drawing-ink-amount` | how much of its hue a coloured text takes, mixed toward the ink; 80% when a theme does not set it |
| `--drawing-kind-ink` | the text in a coloured box |
| `--drawing-line`, `--drawing-line-secondary`, `--drawing-edge` | a drawing's rules, its secondary lines, and their width |
| `--drawing-radius` | a drawn box's corners |
| `--callout-border`, `--callout-rule`, `--callout-radius`, `--callout-padding`, `--callout-font-size` | a callout's frame, its left rule, corners, padding and text size |
| `--callout-label-size`, `--callout-label-case`, `--callout-label-tracking`, `--label-padding` | a callout label's size, case, spacing and padding |
| `--comment-shift` | how far a comment shifts to the right of the text column, on a screen at least 60rem wide |
| `--quote-rule`, `--quote-font-size`, `--quote-style` | a quote's rule, text size and style |
| `--flow-column-min`, `--flow-gap`, `--step-border` | a flow's column width, the gap between steps, and the border of a step and of a todo's box |
| `--ui-dialog-width`, `--ui-form-width`, `--ui-form-label` | a dialog's width, a form's width, and its labels' width |
| `--ui-dialog-border`, `--ui-dialog-radius`, `--ui-control-radius`, `--ui-dialog-shadow` | a screen's border, corners, a control's corners, and its shadow |
| `--ui-flow-gap` | the gap between the screens of a flow |
