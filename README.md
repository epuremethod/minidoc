# minidoc

A small documentation website generator. It discovers YAML configs by glob;
each config declares variables and build outputs. Minidoc renders every
`{{var}}` reference and writes each resolved `input` to its `output` path.

```yaml
var:                      # this config's context
  site: Marmot Docs
base: baseConfig.yaml     # optional: templates inherited from another config
build:
  - var:                  # each build extends the context
      title: Home
    output: "{{lang}}/home.html"   # output paths are templates too
    input: |-
      <h1>{{site}} - {{title}}</h1>
```

## The model

One idea drives everything:

> A **context** is a dictionary of templates. A child context is the parent's
> templates merged with its own — own wins. Everything renders in its nearest
> context.

So a `base` config, the config's `var`, a build's `var`, a content file's
frontmatter: each is just a layer merged into the next context. Precedence is
merge order, nothing more.

The one sentence worth memorizing: **you inherit formulas, not values.** A
base declaring `layout: "<h1>{{title}}</h1>"` doesn't hand you a rendered
string — the template becomes *yours* and resolves against *your* `title`,
like copying a spreadsheet: you copy the formulas, and they recompute against
your cells.

```yaml
# baseConfig.yaml
var:
  layout: "<h1>{{title}}</h1>"
# config.yaml
base: baseConfig.yaml
build:
  - var: { title: Home }
    output: home.html
    input: "{{layout}}"        # -> <h1>Home</h1>
```

Undefined variables and reference cycles fail loud, naming the build entry
and the variable path. Plain name substitution — no filters, no expressions.

To render a reference as literal text, backtick-quote the name:
``{{`name`}}`` outputs `{{name}}` without evaluation, and the name needs no
var. Only the quotes are removed, so the spacing you wrote survives —
``${{ `github.sha` }}`` outputs `${{ github.sha }}`, which is what makes the
escape usable for documenting templating languages of your own.

What comes out is text, not a template: the literal stays literal however far
it travels — through an outer var, a file var importing another, a `dir` or
`list` item, a transform. A rendered result is never re-rendered, so an escape
unwraps exactly once, where it was written.

Under the hood each context is a [tilia](https://tiliajs.dev) carve: every
var is a lazy, cached, dependency-tracked computed. (Fittingly, tilia's own
documentation is built with minidoc — tilia all the way down.)

## Var kinds

Every var is a template plus, optionally, a source and a transform. A plain
string is just a template. A mapping picks a kind by its key:

**`file`** loads its template from an html/md file:

```yaml
var:
  intro:
    file: content/intro.md       # markdown -> html, inferred from extension
  snippet:
    file: content/raw.md
    transform: none              # explicit override of the inference
```

The transform is inferred from the extension (`.md`/`.markdown` -> `md`,
`.html`/`.htm` -> `none`); an unknown extension without an explicit
`transform` fails loud. `{{refs}}` in the body render first, then the
transform runs — so a var can inject markdown that gets rendered.

A content file may start with a YAML frontmatter block of scalars and scalar
lists. The body renders in a child context of that frontmatter, and — for
single `file` vars — the frontmatter also merges into the declaring context,
just below its explicit vars (so an explicit `var: title:` wins). Two files
in one block exporting the same name is a conflict and fails loud. Dots are
ordinary characters in names, so dotted namespaces like `signature.ts` are
fine.

**`dir`** loads a folder of content files and renders each through an `each`
template — the building block for a guide or an API reference:

```yaml
var:
  toc:
    dir: guide
    each: '<li><a href="#{{slug}}">{{title}}</a></li>'
  chapters:
    dir: guide                   # the same folder, a second view
    each: '<section id="{{slug}}">{{body}}</section>'
```

Each item's `each` renders in a child context of the file's frontmatter plus
its rendered content as `{{body}}`; items join with newlines, in filename
order (prefix files `01-intro.md` to control it). `glob` (default `*.md`)
selects files; `transform` overrides the per-file inference. Unlike `file`
vars, items do *not* export their frontmatter outward — eight chapters would
conflict on `title`; it stays local to each item. An empty match fails loud.

**`list`** renders a scalar list (from config or frontmatter) through an item
template. `each` sees the scalar as `{{item}}`; an optional `template` wraps
the `join`ed items as `{{body}}`. An empty list renders nothing, wrapper
included:

```yaml
var:
  refsBlock:
    list: refs
    each: '<a href="./api.html#{{item}}">{{item}}</a>'
    join: ", "
    template: '<p>Reference: {{body}}</p>'
```

**`value`** renders an inline template through a named transform. Because you
inherit formulas, a `value` var declared once re-renders wherever it is used —
inside a dir's `each` it sees that item's frontmatter:

```yaml
var:
  signatureHtml:
    value: "{{signature.ts}}"
    transform: typescript
  entries:
    dir: api
    each: "{{signatureHtml}}{{body}}"   # per-item signature, one declaration
```

## Build entries

A build's `input` is a template string, or a `file`/`dir` mapping behaving
like the matching var kind. A file input's frontmatter merges in as the least
local layer — usable even in the output path:

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

An input with a `copy` key copies a file or directory (recursively) without
reading or rendering its content. The paths may contain `{{refs}}`; the
copied bytes never do:

```yaml
build:
  - output: public/style.css
    input: { copy: assets/style.css }
  - output: public/fonts
    input: { copy: assets/fonts }
```

## Paths — the one exception

Declared paths (`base`, `output`, `file`, `dir`, `copy`) are relative to the
config file that declares them, anchored at parse time. Paths may contain
`{{refs}}`, but they resolve against plain string vars only — paths must
resolve before content loads, so they can never depend on it. Refs can
contribute path segments but never move the anchor; absolute paths (`/...`)
pass through untouched.

## Usage

```ts
import { run } from "@epure/minidoc"
import { apiMd, typescript } from "./transforms.ts"

await run({
  glob: "content/**/config.yaml",
  transform: { apiMd, typescript },
})
```

Custom transforms extend or override the built-in registry (`md` renders
markdown via marked, `none` passes through). Runs update declared outputs in
place and never clean old output first, so a live server keeps serving the
previous files until replacements are written.

Inject a filesystem for a browser, test, or other non-Node environment — the
Node adapter loads lazily only when `fs` is omitted:

```ts
import { run, nodeFs, makeMemoryFileSystem } from "@epure/minidoc"

await run({ fs: makeMemoryFileSystem(files), glob: "**/config.yaml" })
await run({ fs: nodeFs(new URL("./content/", import.meta.url)), glob: "**/config.yaml" })
```

## Design

Three source files, ReScript:

- `src/Schema.res` — [Sury](https://github.com/DZakh/sury) schemas parsing
  YAML configs and frontmatter into tagged variants; path anchoring.
- `src/Minidoc.res` — contexts (tilia carves), rendering, the filesystems,
  `run`. All I/O goes through the injected `filesystem`; transforms are
  injected too.
- `src/Minidoc.resi` — the public interface, mirrored by the hand-written
  `src/Minidoc.res.d.mts` for TypeScript consumers.

## Tests

```sh
pnpm test
```

Tests are declarative YAML fixtures (`test/*.test.yaml`) driving the public
API against the in-memory filesystem: each scenario is a `source` filesystem
and either a `target` of expected outputs or the `error` the run must reject
with. Failures source-map back to the scenario's line in the YAML file. The
fixtures run through `epureVitest`; their shared `Given` is registered in
`test/steps.ts`.
