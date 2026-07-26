# minidoc

A small documentation website generator. It reads a YAML config describing
variables, optional `base` config inheritance, and build outputs; resolves
every `{{var}}` reference to a fixpoint; and writes each resolved `input` to
its `output` path.

```yaml
var:                      # global variables
  site: Marmot Docs
base: baseConfig.yaml     # optional: vars inherited from another config
build:
  - var:                  # build-local variables (most local scope)
      title: Home
    output: "{{lang}}/home.html"   # output paths are templates too
    input: |-
      <h1>{{site}} - {{title}}</h1>
```

Scopes, most local first: `build[n].var`, then `var`, then the `base`
chain. Values may reference other variables; resolution re-substitutes until
stable. Undefined variables and reference cycles fail loud, naming the build
entry, the variable, and the scopes searched.

v1 is plain name substitution only — no escaping of literal `{{`/`}}`, no
filters/pipes, no expressions (future extensions).

## File vars

A var value that is a mapping with a `file` key loads its content from an
html/md file instead of inline text:

```yaml
var:
  intro:
    file: content/intro.md       # markdown -> html, inferred from extension
  footer:
    file: partials/footer.html   # html, passed through as-is
  snippet:
    file: content/raw.md
    transform: none              # explicit override of the inference
```

The transform is inferred from the extension (`.md`/`.markdown` -> `md`,
`.html`/`.htm` -> `none`); an unknown extension without an explicit
`transform` fails loud. `{{refs}}` in the body are resolved first, then the
transform runs on the result (so a var can inject markdown that gets
rendered).

Content files may start with a YAML frontmatter block of scalar vars:

```markdown
---
title: Home
---
# {{title}}
```

Frontmatter is the most local scope for the file's own body, and its vars are
also exported as a scope just below the declaring `var` block — so a build
layout can use `{{title}}` from its content file, while an explicit
`var: title:` still wins. Two files in one block exporting the same name is a
conflict and fails loud.

## Dir vars

A var value with a `dir` key loads a whole folder of content files, renders
each through the `each` template, and joins the items with newlines — the
building block for a guide or an API reference:

```yaml
var:
  toc:
    dir: guide                   # like `file`: anchored to this config
    each: '<li><a href="#{{slug}}">{{title}}</a></li>'
  chapters:
    dir: guide                   # the same folder, a second view
    each: |-
      <section id="{{slug}}">{{body}}</section>
  coreIndex:
    dir: api
    where: { module: core }      # keep files whose frontmatter matches
    each: '<a href="#{{slug}}">{{name}}</a>'
```

`each` is expanded once per file with, most local first: the file's
frontmatter, then `body` (the file's content, transformed like a file var),
then the normal outer scopes; it defaults to `{{body}}` (bare concatenated
files). Files render in filename order — prefix them (`01-intro.md`) to
control it. `glob` (default `*.md`, `*` wildcard only) selects files by
basename; `transform` overrides the per-file extension inference for every
file.

Unlike single file vars, a dir var does not export its files' frontmatter to
the declaring scope (eight chapters would conflict on `title`); frontmatter
stays local to each item. Zero matched files — empty folder, glob or `where`
matching nothing — fails loud.

## Build input

A build entry's `input` may be a file or dir mapping directly, instead of a
template string that references a var:

```yaml
build:
  - output: "{{slug}}.html"      # slug from the file's frontmatter
    input:
      file: content/home.md
  - output: guide.html
    input:
      dir: content/guide
      each: "<section>{{body}}</section>"
```

It behaves like the matching var kind: a file input exports its frontmatter
(least local, so an explicit build var wins), usable even in the output path;
a dir input keeps frontmatter local to each item.

An input with a `copy` key copies one file or directory without reading,
transforming, or resolving its content:

```yaml
build:
  - output: public/style.css
    input:
      copy: assets/style.css
  - output: public/fonts
    input:
      copy: assets/fonts
```

Directory copies are recursive. The `copy` and `output` paths may contain
`{{refs}}`, but copied bytes—including text containing `{{refs}}`—remain
unchanged.

## Paths

Every declared path (`base`, `output`, `file`, `dir`, `copy`) is relative to
the config file that declares it, anchored at parse time — before var
interpolation. Input paths may contain `{{refs}}`; they resolve against string
vars only (never frontmatter or file contents) and can contribute segments,
but never move the anchor. Absolute paths (`/...`) pass through untouched.

## Usage

```sh
pnpm minidoc <configPath>
```

## Design

- `src/api/` — types only (the `FileSystem` service interface, config, scope
  and transform types).
- `src/services/` — one file per service: `makeMemoryFileSystem` backs the
  tests, `makeNodeFileSystem` backs real runs, `makeTransforms` wraps the
  markdown renderer (`marked`).
- `src/features/` — pure logic (`resolve`, `parseConfig`, `splitFrontmatter`,
  `run`): all I/O goes through the injected `FileSystem`, transforms are
  injected too, never direct `fs`/`path`/renderer imports.
- `src/index.ts` — public surface and composition point: exports `run` with
  the default transform registry pre-wired.
- No classes: services are `make...()` factories returning plain objects of
  closures.

## Tests

```sh
pnpm test
```

Tests are declarative YAML fixtures (`test/*.test.yaml`): a `feature` title
names the suite, `background` names the `given` step that runs every
scenario, and each `examples` entry is pure data for that step:

```yaml
feature: Variable resolution
background:
  given: a filesystem
examples:
  - scenario: it should resolve variables from var
    source:            # virtual filesystem the run starts with
      config.yaml: ... # mapping values are serialized back to YAML text
    target:            # expected filesystem contents after the run
      out.html: ...
    # or error: the message the run must reject with
```

The `yaml-bdd/` modules split along the extraction line into `@epure/vitest`:

- `compile.ts` — generic yaml parsing, validation and source-mapped codegen;
  knows nothing about what a scenario means.
- `steps.ts` — the step registry (`given(key, fn)`) and runtime.
- `plugin.ts` — Vite glue; resolves each fixture to its steps module the same
  way @epure/vitest does (`base.test.ts`, `base.steps.ts`, then a shared
  `steps.ts` next to the fixture).
- `test/steps.ts` — minidoc's only step, `a filesystem`: seeds the in-memory
  FileSystem from `source`, runs the entry `config.yaml`, asserts `target`
  files (or the `error`). Uses only minidoc's public API.

Failures stack through the step definition and source-map back to the
scenario's line in the YAML file.
