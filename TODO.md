# TODO — build the @epure/vitest docs with minidoc

Target: `../vitest/docs` (content in `content/epurejs/`, output in
`../vitest/dist`). Every item below was verified against the real content
files and the output the previous implementation left in `../vitest/dist` —
not guessed from the old config schema. The old `document`/`templates`/
`parser` config format will be rewritten to the lean vars model; only the
capabilities below are actually missing.

## 1. Folder-based page build (collections)

- [x] Done: dir vars (`dir`/`each`/`glob`/`transform`, filename order) — see "Dir vars" in README.md.

## 2. Richer frontmatter values

- [x] Done: exact dotted names such as `signature.ts` and `signature.res`
  provide one flat variable rule in config and frontmatter.
- [x] Done: scalar lists render through list vars (`list`/`each`/`join`/
  `template`); an empty list renders nothing, including its wrapper.

## 3. Markdown transform extensions (keep out of core)

The old build's `md` transform did several things `marked` alone does not.
`run({ transform })` takes an injected transform registry. The docs project
can call minidoc's API from a small build script, keeping these
project-specific transforms out of minidoc:

- `story`, `pro`, and `def` containers.
- Build-time syntax highlighting of fences: Prism token markup for
  `typescript`, `rescript`, and `gherkin` using Prism's stock components.
- Fence pairing: consecutive `typescript` + `rescript` fences merge into
  one `figure[data-pair]` with a TS/RES toggle; a `gherkin` fence becomes
  a "Contract" figure, and gherkin followed by a ts/res pair becomes the
  feature/steps view-switch figure used on the api page.
- [x] Done in core: transform vars apply a named transform to a resolved
  inline value, including item-local dotted frontmatter such as
  `signature.ts` and `signature.res`.

## 4. Asset copy

- [x] Done: unified `build` entries support opaque `input.copy` for single
  files and recursive directories, with source and output paths anchored like
  every other declared path. Copies bypass the string `FileSystem.readFile`,
  preserving binary content.

## 5. Project build and dev

- [x] Done in core: `watch` and `dev` (`src/Dev.res`). A docs project keeps its
  own `build.ts` calling `run()`; `dev({glob, build})` watches the project,
  rebuilds it in a fresh process — so an edited transformer takes effect — and
  serves the output with live reload on a port drawn once and remembered in the
  entry config. No CLI, and no chokidar or live-server in the docs projects.

## 6. Programmatic config access

- [x] No config-loader API needed: docs tests assert generated behavior
  through the public `run()` surface.

## Checked and NOT needed

- **Publication dates**: no date/published/updated metadata anywhere in
  the content or the built output — skip the frontmatter-date idea.
- **Heading anchors**: `###` headings inside chapters have no ids in the
  old output; only chapter/entry slugs (from frontmatter) are anchored,
  and the templates already handle those.
- **Deep build merge across the `base` chain**: the old format merged
  `pages.*` from base configs; in the lean model shared shell/header/
  footer/templates are base *vars* and build entries are declared once in
  the entry config.
- **Sitemap, RSS, search, minification**: none in the old output.
