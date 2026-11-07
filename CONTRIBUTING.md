# Contributing

This project follows the [épure](https://epuremethod.com) method.

## Working agreement

1. **Scenarios define behavior.** Write or change the scenario before changing
   behavior. Use the audience's vocabulary. A bug needs a scenario that
   reproduces it.
2. **Keep one current design.** Remove temporary designs when the scenarios
   replace them. Record lasting reasons in `DECISIONS.md`: date, decision,
   rejected alternative, and cost. Do not use it as a work log.
3. **Passing checks complete the work.** The scenarios and standing checks
   must pass. Step definitions are production-quality code. An incorrect step
   can hide incorrect behavior.

## Packages

One pnpm workspace. The root holds no code.

- `packages/core/` is the generator, package `@minidoc/core`.
- `packages/blocks/` is the common `:::` blocks, package `@minidoc/blocks`:
  a line scanner, readers into nodes, the nodes' text form, each block's
  drawing in a JSX of its own, `Draw`, written as HTML, `blocks.css`, two
  themes, and `viewer.js`, which opens a drawing full screen. Its scenarios
  are `packages/blocks/test/*.test.yaml`, and the site draws them on its
  Blocks page.
- `packages/live/` is `@minidoc/live`: the same drawings as React
  elements, a block's source read into a value that keeps a refusal, a
  pane that holds the source, and an editor that draws a plan's fields as
  inputs. The edits themselves are in `@minidoc/blocks`. It runs in jsdom,
  its own scenarios and the blocks' `html.test.yaml`.
- `packages/edit/` is `@minidoc/edit`, private: a page of a site as its
  editor in `dev`. minidoc reads each file's markdown into the blocks of
  the tilia editor, as CommonMark groups it, draws them with live, and
  writes the file back, changing only the blocks the person edited. It
  depends on `@tilia/editor` and `@epure/editor`, linked from `../editor`
  until they are on npm. Its scenarios run in jsdom.
- `packages/deprecated/` is `@epure/minidoc`, the former name. It
  re-exports `@minidoc/core` and is published deprecated.
- `packages/docs/` is the documentation site, package `minidoc-docs`, private. It is
  built with minidoc and deployed to GitHub Pages on every push to `main`.

`pnpm build` at the root builds the package, then the site. `pnpm docs:dev` serves
the site with minidoc's own dev server, each page an editor of its markdown.

`pnpm pub <core|blocks|deprecated>` at the root publishes a package at the
version in its `package.json`, from a clean tree, after `pnpm check`. It tags
core `v0.2.0` and blocks `blocks-v0.1.0`; `@epure/minidoc` gets no tag and
is marked deprecated on npm. `--beta` publishes a dated beta and tags
nothing. Publish core before `@epure/minidoc`, which depends on it.

## Scenarios

The scenarios are YAML fixtures in `packages/core/test/*.test.yaml`, run by
`@epure/vitest`. A fixture is a `feature` with a `background` naming its
`given`, and `examples`, one `scenario` each. A scenario has a `source`
filesystem, optional run `options`, and either a `target`, the expected
outputs, or the `error` the run must reject with. The steps file,
`packages/core/test/steps.ts`, binds the `given`. It runs the public API against
the in-memory filesystem.

Two things cannot run on the in-memory filesystem, and they have plain
`node --test` files instead:

- `test/dev.test.mjs` drives `dev` and `watch` against a real filesystem and
  a real socket.
- `test/package.test.mjs` checks the packed package.

`pnpm check` at the root is the standing check. In `packages/core/` it runs the
fixtures, the dev tests and the package test; in `packages/blocks/` the scenarios;
in `packages/live/` its scenarios and the blocks' HTML contract, drawn live;
in `packages/edit/` its scenarios; in `packages/docs/` the site's build, which
fails when a plate cannot be drawn, then every docs page read into the
editor and written back byte for byte, a word changed in each block
changing only that block, and a static build with nothing of the editor.

`pnpm live:hit` at the root is the hit check. It draws each block that has
inputs, in editing mode, and asks headless Chrome whether each field and
act takes the click at its centre. jsdom has no layout, so the scenarios
cannot see a drawing's pseudo-element over a button. It also draws plans
with a stand-in for a host's text field, and checks that each text in it
has the font, size, colour and place of the same text on a static page,
and that a long plan's side list is a third of its width. Run it at the end of every build that touches live, `blocks.css` or a
theme. It needs Chrome or Chromium, or `CHROME` set to its path, so it
stays out of `pnpm check`, which CI runs.

`pnpm docs:edit-check` at the root is the editor's check in Chrome, on a
copy of the docs. Typing keeps the caret and writes the file, a drawing
opens its source in the panel and follows each key, a save by another
program reloads the page, and the edited text looks as on the static page,
word by word. Run it at the end of every build that touches `@minidoc/edit`,
the docs' dev page, or the editor.

## Architecture

```
packages/core/src/
  Schema.res         config and frontmatter schemas, path anchoring, the port
  Minidoc.res        contexts, rendering, the filesystems, run
  Minidoc.resi       the public interface
  Minidoc.res.d.mts  the same interface for TypeScript, written by hand
  Dev.res            watch and dev: the watcher, the rebuild loop, the server
```

All input and output goes through the injected `filesystem`. Transforms are
injected too. `Minidoc.res` never imports a Node module.

`Dev.res` is Node-only. It loads every builtin through a dynamic import, so
importing minidoc in a browser stays safe.

`Minidoc.resi` and `Minidoc.res.d.mts` change together.

## Session order

One session handles one bounded goal.

1. Write `SESSION.md`: what will change, why, and who it serves.
2. Write the fixture with its scenarios.
3. Add the implementation approach and rejected alternatives to `SESSION.md`.
4. Bind the scenarios in the steps file.
5. Build until the scenarios and standing checks pass.

Stop after each stage and wait for agreement. Do not present several stages
as finished together. Do not write steps or build before the fixture is
agreed.

When the session is green, append only lasting decisions to `DECISIONS.md`
and clear `SESSION.md`. The scenarios remain.

## Documentation

The reference lives twice: in `packages/core/README.md` and in the site's API,
`packages/docs/content/api/`, one file per entry. The site's guide,
`packages/docs/content/guide/`, tells the same features as one story, one file
per chapter. A change to behavior changes all three where it shows. The build
writes `llms.txt` and `llms-full.txt` from the guide and the API.

Every change a user can see gets a line under "Unreleased" in the changelog
of `packages/core/README.md`. A change that breaks an existing config, a custom
filesystem or a caller starts with **Breaking:**.

## Writing

Write plain, natural English. Use common words, short sentences, active
voice, and concrete subjects. Put one claim in each sentence. Keep the
domain's exact vocabulary: config, build entry, var, context, template,
frontmatter, transform, output. Avoid metaphors, idioms and clever phrasing.

Use comments only for a domain rule, an external quirk, or an invariant that
the code and types cannot express. Keep them beside what they describe. Do
not comment fixtures. Put lasting rationale in `DECISIONS.md`. Delete stale
comments after changing code.

## Library references

Before using a library, read its version-matched
`node_modules/<package>/llms.txt` or `README.md`. If the reference does not
describe an API, ask before using it.
