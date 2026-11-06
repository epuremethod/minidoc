# Agents

Read `CONTRIBUTING.md` and `DECISIONS.md` first.

## Commits

Commit only when asked. A commit message is one line, with no body and no
trailer, in the present tense and affirmative: "Add a plan block", not
"Added a plan block" or "Don't draw empty plans". One commit per feature.

## Blocks take their colours from the theme's fixed variables

Every block reads the same fixed set of variables, so that all blocks look
alike within a theme. Do not add a variable, and never write a colour
literal in `blocks.css`, to style one block.

- A theme sets variables and nothing else, under `[data-blocks-theme]`.
- The neutrals are `--blocks-*`: ink, muted, line, stroke, surface, canvas,
  band, band-ink.
- A block's colour is `--tone`, set on the block from a `--tone-*` variable.
  A theme never names `--tone`.
- A fill, an edge or a label is mixed from `--tone` and `--blocks-surface`
  by the theme's amounts: `--fill-amount`, `--edge-amount`, and
  `--drawing-fill-amount` and `--drawing-edge-amount` for drawings.
- Shapes are variables too: radii, padding, borders and gaps.

To make something primary or secondary, pick the existing variable that
already plays that role in other blocks, such as `--blocks-muted` or
`--drawing-line`. Only a look that no variable describes justifies a new
one. In that case, ask first, add the new variable to every theme, and
record it in `DECISIONS.md`.

Source: `DECISIONS.md`, 2026-10-03, "A theme sets variables, and never
names --tone", and `packages/docs/content/blocks/10-contracts.md`.
