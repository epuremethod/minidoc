# Agents

Read `CONTRIBUTING.md` and `DECISIONS.md` first.

## Commits

Commit only when asked. Never commit on your own initiative.

A commit message is one line, with no body and no trailers. Write it in the
present tense, as an affirmative sentence: "Add a plan block".

## Blocks take their colours from the theme's fixed variables

Every block reads the same fixed set of variables, so that all blocks look
alike within a theme. Do not add a variable, and never write a colour
literal in `blocks.css`, to style one block.

- A theme sets variables and nothing else, under `[data-blocks-theme]`.
- The neutrals are `--blocks-*`: ink, muted, line, stroke, surface, canvas,
  band, band-ink.
- A block's colour is `--tone`, set on the block from a `--tone-*` variable,
  or from a `--hue-*` variable of the palette when a drawing asks for a
  `color`. A theme never names `--tone`.
- A fill, an edge or a label is mixed from `--tone` and `--blocks-surface`
  by the theme's amounts: `--fill-amount`, `--edge-amount`, and
  `--drawing-fill-amount`, `--drawing-edge-amount` and
  `--drawing-ink-amount` for drawings. A coloured text mixes toward
  `--blocks-ink` instead, so it stands out from the surface.
- Every variable a theme sets is listed in `05-contracts.md` and in
  llms.txt (`docs/content/llms.yaml`); `blocks/test/themes.test.yaml`
  checks the themes and both lists.
- Shapes are variables too: radii, padding, borders and gaps.

To make something primary or secondary, pick the existing variable that
already plays that role in other blocks, such as `--blocks-muted` or
`--drawing-line`. Only a look that no variable describes justifies a new
one. In that case, ask first, add the new variable to every theme, and
record it in `DECISIONS.md`.

Source: `DECISIONS.md`, 2026-10-03, "A theme sets variables, and never
names --tone", and `packages/docs/content/blocks/05-contracts.md`.
