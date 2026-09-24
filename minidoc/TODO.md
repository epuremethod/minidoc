# TODO — build the @epure/vitest docs with minidoc

Target: `../vitest/docs` (content in `content/epurejs/`, output in
`../vitest/dist`). Every item was verified against the real content files and
the output the previous implementation left in `../vitest/dist` — not guessed
from the old config schema. The old `document`/`templates`/`parser` format
will be rewritten to the lean vars model; only the capabilities below were
actually missing.

## Done

- **Folder-based page build (collections)** — `dir`/`each`/`glob`/`transform`,
  filename order. See "Dir vars" in README.md.
- **Dotted frontmatter names** — `signature.ts`, `signature.res`: exact dotted
  names are ordinary characters, one flat variable rule in config and
  frontmatter.
- **Scalar lists** — `list`/`each`/`join`/`template`; an empty list renders
  nothing, including its wrapper.
- **Transform vars** — `value` applies a named transform to a resolved inline
  value, including item-local dotted frontmatter.
- **Asset copy** — `input.copy` for single files and recursive directories;
  paths anchored like every other declared path; copies bypass the string
  `FileSystem.readFile`, preserving binary content.
- **Project build and dev** — `watch` and `dev` (`src/Dev.res`). A docs
  project keeps its own `build.ts` calling `run()`; `dev({glob, build})`
  rebuilds in a fresh process and serves with live reload on a port drawn
  once and remembered in the entry config.
- **Programmatic config access** — not needed: docs tests assert generated
  behavior through the public `run()` surface.

## Project-specific transforms (keep out of core)

The old build's `md` transform did several things `marked` alone does not.
`run({ transform })` takes an injected transform registry; the docs project
can call minidoc's API from a small build script:

- `story`, `pro`, and `def` containers.
- Build-time syntax highlighting of fences: Prism token markup for
  `typescript`, `rescript`, and `gherkin` using Prism's stock components.
- Fence pairing: consecutive `typescript` + `rescript` fences merge into one
  `figure[data-pair]` with a TS/RES toggle; a `gherkin` fence becomes a
  "Contract" figure; gherkin followed by a ts/res pair becomes the
  feature/steps view-switch figure on the api page.

## Checked and NOT needed

- **Publication dates** — no date/published/updated metadata in the content
  or the built output.
- **Heading anchors** — `###` headings carry no ids; only chapter/entry slugs
  are anchored, and the templates already handle those.
- **Deep build merge across the `base` chain** — the old format merged
  `pages.*` from base configs; in the lean model shared shell/header/footer
  are base *vars* and build entries are declared once in the entry config.
- **Sitemap, RSS, search, minification** — none in the old output.
