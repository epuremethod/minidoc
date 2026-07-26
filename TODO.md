# TODO — build the @epure/vitest docs with minidoc

Target: `../vitest/docs` (content in `content/epurejs/`, output in
`../vitest/dist`). Every item below was verified against the real content
files and the output the previous implementation left in `../vitest/dist` —
not guessed from the old config schema. The old `document`/`templates`/
`parser` config format will be rewritten to the lean vars model; only the
capabilities below are actually missing.

## 1. Folder-based page build (collections)

- [x] Done: dir vars (`dir`/`each`/`glob`/`where`/`transform`, filename order) — see "Dir vars" in README.md.

## 2. Richer frontmatter values

- [x] Done: nested mappings such as `signature: {ts: ..., res: ...}` resolve
  through dotted paths such as `{{signature.ts}}`.
- [x] Done: scalar lists render through list vars (`list`/`each`/`join`/
  `template`); an empty list renders nothing, including its wrapper.

## 3. Markdown transform extensions (keep out of core)

The old build's `md` transform did four things `marked` alone does not.
`run()` already takes an injected transform registry — the lean path is a
supported way for the docs project to provide its own registry (a config
key naming a module, or the docs calling minidoc's API from a small build
script), keeping these project-specific transforms out of minidoc:

- `::: story` container → `<div class="story">` (guide chapters).
- Build-time syntax highlighting of fences: Prism token markup for
  `typescript`, `rescript`, and `gherkin` (custom grammar — keyword,
  table-row and French-language tokens appear in the output).
- Fence pairing: consecutive `typescript` + `rescript` fences merge into
  one `figure[data-pair]` with a TS/RES toggle; a `gherkin` fence becomes
  a "Contract" figure, and gherkin followed by a ts/res pair becomes the
  feature/steps view-switch figure used on the api page.
- The nested `signature.ts`/`signature.res` strings are highlighted too
  (the `sig-wrap` pair) — highlighting must be callable on a var, not only
  on fences.

## 4. Asset copy

- [x] Done: unified `build` entries support opaque `input.copy` for single
  files and recursive directories, with source and output paths anchored like
  every other declared path. Copies bypass the string `FileSystem.readFile`,
  preserving binary content.

## 5. CLI: `build` and `dev`

`docs/package.json` runs `minidoc build` and `minidoc dev` (live-server
does the serving and reload; minidoc only needs to rebuild):

- subcommands with a config path argument (current CLI is bare
  `minidoc <configPath>`);
- `dev` = watch the config chain + content files and rerun the build.

## 6. Programmatic config access

`docs/src/build.test.mjs` imports `loadConfig` from `@epure/minidoc/build`
to assert the resolved config (paths and build outputs, including copies).
Expose an equivalent from the public API — or rewrite those tests against
the new surface when the docs config is redone.

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
