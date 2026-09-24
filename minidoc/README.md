# minidoc

A small documentation website generator. YAML configs declare variables and
build outputs; minidoc renders every `{{var}}` reference and writes each
resolved `input` to its `output` path.

```yaml
var:
  site: Marmot Docs
  lang: en
build:
  - output: "{{lang}}/home.html"   # output paths are templates too
    input: "<h1>{{site}}</h1>"
```

```ts
import { run } from "@epure/minidoc"

await run({ glob: "content/**/config.yaml" })
```

## Starting a documentation website

1. **Design.** Find a design, or vibe-code one. The look is yours — HTML,
   CSS, fonts. minidoc fills in the content. Start from a base `index.html`
   layout — one HTML shell, shared by every page.
2. **Install.** Add `@epure/minidoc`, write a config and a `run`, as above.
3. **Ask an agent to write the docs.** At minimum give it the list of pages
   you want, and how the markdown sources should be organised — one file
   per concept, one file per method, one file per chapter. Fix the shape
   first; the agent fills the files.
4. **Dev server.** `dev()` watches, rebuilds, and live-reloads — see
   [Development](#development) — and the site takes shape as the files land.

The base layout, its config, and a `run`:

```html
<!-- content/layout.html — the base index.html layout -->
<!doctype html>
<html lang="{{lang}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{title}}</title>
<link rel="stylesheet" href="styles.css">
</head>
<body>
<main>{{main}}</main>
</body>
</html>
```

```yaml
# content/config.yaml
var:
  site: Marmot Docs
  lang: en
  layout:
    file: layout.html
build:
  - output: index.html
    input: "{{layout}}"
    var:
      title: "{{site}}"
      main: "<h1>{{site}}</h1>"
  - output: styles.css
    input: { copy: styles.css }
```

```ts
// build.mjs
import { run } from "@epure/minidoc"

await run({ glob: "content/**/config.yaml" })
```

For a complete worked example — layout, pages, config, `run`, and dev
server — see
[the docs source](https://github.com/epuremethod/minidoc/tree/main/docs)
(this documentation site, built with minidoc).

## The model

One rule:

> A **context** is a dictionary of templates. A child context is the parent's
> templates merged with its own — own wins. Everything renders in its nearest
> context.

A `base` config, the config's `var`, a build's `var`, a content file's
frontmatter: each is a layer merged into the next context. Precedence is
merge order.

**You inherit formulas, not values.** A base declaring
`layout: "<h1>{{title}}</h1>"` does not hand you a rendered string — the
template becomes yours and resolves against your `title`, like copying a
spreadsheet: the formulas come along and recompute against your cells.

```yaml
# baseConfig.yaml
var:
  layout: "<h1>{{title}}</h1>"
```

```yaml
# config.yaml
base: baseConfig.yaml
build:
  - var: { title: Home }
    output: home.html
    input: "{{layout}}"        # -> <h1>Home</h1>
```

Substitution is plain name lookup — no filters, no expressions. Undefined
names and reference cycles fail loud with their site and line (see
[Errors](#errors)).

Under the hood each context is a [tilia](https://tiliajs.dev) carve: every
var is a lazy, cached, dependency-tracked computed. (tilia's own
documentation is built with minidoc.)

## Escaping a reference

Backtick-quote the name: ``{{`name`}}`` outputs `{{name}}` without
evaluation, and the name needs no var. Only the quotes are removed, so the
spacing you wrote survives — ``${{ `github.sha` }}`` outputs
`${{ github.sha }}`. That is what makes the escape usable for documenting
templating languages of your own.

What comes out is text, not a template: the literal stays literal however far
it travels — through an outer var, a file var importing another, a `dir` or
`list` item, a transform. A rendered result is never re-rendered, so an
escape unwraps exactly once, where it was written.

## Var kinds

Every var is a template plus, optionally, a source and a transform. A plain
string is just a template; a mapping picks a kind by its key:

| kind | source | renders |
|------|--------|---------|
| `file` | one html/md file | the body |
| `dir` | a folder of content files | each item through `each`, newline-joined |
| `list` | a scalar list | each item through `each`, joined by `join` |
| `value` | an inline template | the template through a named transform |

### `file`

Loads its template from an html/md file:

```yaml
var:
  intro:
    file: content/intro.md       # markdown -> html, inferred from extension
  snippet:
    file: content/raw.md
    transform: none              # explicit override of the inference
```

The transform is inferred from the extension (`.md`/`.markdown` → `md`,
`.html`/`.htm` → `none`); an unknown extension without an explicit
`transform` fails loud. `{{refs}}` in the body render first, then the
transform runs — so a var can inject markdown that gets rendered.

A content file may open with a YAML frontmatter block of scalars and scalar
lists. The body renders in a child context of that frontmatter, and — for a
single `file` var — the frontmatter also merges into the declaring context,
just below its explicit vars (so an explicit `var: title:` wins). Two files
in one block exporting the same name fail loud. Dots are ordinary characters
in names, so dotted namespaces like `signature.ts` are fine.

### `dir`

Loads a folder of content files and renders each through an `each` template —
the building block for a guide or an API reference:

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
its rendered content as `{{body}}`. Items join with newlines, in filename
order — prefix files `01-intro.md` to control it. `glob` (default `*.md`)
selects files; `transform` overrides the per-file inference. Unlike `file`
vars, items do *not* export their frontmatter outward (eight chapters would
conflict on `title`); it stays local to each item. An empty match fails loud.

### `list`

Renders a scalar list (from config or frontmatter) through an item template.
`each` sees the scalar as `{{item}}`; an optional `template` wraps the
`join`ed items as `{{body}}`. An empty list renders nothing, wrapper
included:

```yaml
var:
  refsBlock:
    list: refs
    each: '<a href="./api.html#{{item}}">{{item}}</a>'
    join: ", "
    template: '<p>Reference: {{body}}</p>'
```

### `value`

Renders an inline template through a named transform. Because you inherit
formulas, a `value` var declared once re-renders wherever it is used — inside
a dir's `each` it sees that item's frontmatter:

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

Runs update declared outputs in place and never clean old output first, so a
live server keeps serving the previous files until replacements are written.

### Paths — the one exception

Declared paths (`base`, `output`, `file`, `dir`, `copy`) are relative to the
config file that declares them, anchored at parse time. Paths may contain
`{{refs}}`, but they resolve against plain string vars only — paths must
resolve before content loads, so they can never depend on it. Refs can
contribute path segments but never move the anchor; absolute paths (`/...`)
pass through untouched.

## Errors

Every render error is decorated with its site — the file or build entry it
came from — and undefined references in multi-line templates carry a line
number:

```
Undefined variable {{missing}} at line 3 in file content/intro.md
Variable cycle in file content/intro.md: intro -> intro
Undefined variable {{missing}} in build[0] output
```

The innermost site wins: an error is labeled once, where it happened, and not
again on the way out. Line numbers count from the top of the document — the
body keeps its place behind the frontmatter, so a custom transform reporting
"line 26" points at line 26 of the actual file.

By default any error aborts the run. With `inlineErrors: true`, content
errors instead surface as an error box (thin red border, faint red
background, class `minidoc-error`, message HTML-escaped) at their place in
the output page, and each is also logged to the console. The blast radius is
the nearest content boundary: a failing `dir` item boxes only that item, the
rest of the page still renders. Meant for a dev server — the site keeps
building and the error shows up where it happens. Output path errors still
fail loud even in this mode: a file cannot be written without a path. Leave
it off in CI.

```ts
await run({ glob: "content/**/config.yaml", inlineErrors: dev })
```

## API

```ts
import { run } from "@epure/minidoc"
import { apiMd, typescript } from "./transforms.ts"

await run({
  glob: "content/**/config.yaml",
  transform: { apiMd, typescript },
})
```

`run` options:

| option | default | meaning |
|--------|---------|---------|
| `glob` | — | required; selects the entry configs |
| `fs` | Node fs at cwd | injected [filesystem](#filesystems) |
| `transform` | `{}` | added to / overriding `md`, `none` |
| `inlineErrors` | `false` | see [Errors](#errors) |

Custom transforms are plain `(text: string) => string` functions. The
built-in registry has `md` (markdown via marked) and `none` (passthrough).

### Filesystems

All I/O goes through one injected `FileSystem` interface — the only door to
the outside world. Inject one for a browser, test, or other non-Node
environment; the Node adapter loads lazily only when `fs` is omitted:

```ts
import { run, nodeFs, makeMemoryFileSystem } from "@epure/minidoc"

await run({ fs: makeMemoryFileSystem(files), glob: "**/config.yaml" })
await run({ fs: nodeFs(new URL("./content/", import.meta.url)), glob: "**/config.yaml" })
```

## Development

`dev` builds the site, watches the project, rebuilds what changed, and serves
the output with live reload:

```ts
import { dev } from "@epure/minidoc"

await dev({ glob: "content/**/config.yaml", build: "src/build.ts" })
```

Options:

| option | default | meaning |
|--------|---------|---------|
| `build` | — | script that calls `run()`; each rebuild runs it in a fresh process |
| `root` | cwd | watched recursively |
| `watch` | `[]` | extra paths to watch, inside the project or not |
| `ignore` | `dist`, `node_modules`, `lib`, dot-names | never watched |
| `extensions` | `.md` `.yaml` `.html` `.css` + scripts | trigger a rebuild |
| `serve` | `dist` | directory served (`dev` only) |
| `port` | remembered in config | fixed port; writes nothing (`dev` only) |

A rebuild fires on any matching file under `root` — new files included — so
`dist`, `node_modules`, `lib` and every dot-name go unwatched and a build
never triggers itself. One save is several filesystem events, so changes
coalesce; a change arriving mid-build queues exactly one more run, however
many arrive.

`build` is what makes an edited transformer take effect: transforms reach
`run` as closures, and no ESM cache hands back a module a file has changed
under. Without `build`, `dev` calls `run` in its own process with
`inlineErrors` on — fine for a site with no custom transforms, blind to a
transformer edit.

The served page carries one injected line, an `EventSource` that reloads it
when a build lands. The rest is a static host: `/guide/` answers with its
index, `/guide` with `guide.html` then `guide/index.html`, so the dev site is
the deployed site.

`watch` is the same runner without the server, for a project that serves its
output some other way:

```ts
const watcher = await watch({ glob: "content/**/config.yaml", build: "src/build.ts" })
watcher.stop()
```

### The port

A dev server on a fixed port collides with every other project on the
machine. So the port is drawn once, free, and written back to the entry
config — under `var`, like any other scalar:

```yaml
var:
  site: Marmot Docs
  port: 51234        # written on first launch
```

The site keeps that address for good: bookmarkable, and `{{port}}` is an
ordinary var a template can print. The config is rewritten through yaml's
document API, so comments and layout survive. The day that port is taken, a
free one replaces it in the file. Passing `port` explicitly skips all of this
and writes nothing.

## Design

Three source files, ReScript, plus the dev runner:

- `src/Schema.res` — [Sury](https://github.com/DZakh/sury) schemas parsing
  YAML configs and frontmatter into tagged variants; path anchoring, and the
  remembered port.
- `src/Minidoc.res` — contexts (tilia carves), rendering, the filesystems,
  `run`. All I/O goes through the injected `filesystem`; transforms are
  injected too.
- `src/Minidoc.resi` — the public interface, mirrored by the hand-written
  `src/Minidoc.res.d.mts` for TypeScript consumers.
- `src/Dev.res` — `watch` and `dev`: the watcher, the rebuild loop, the
  static server. Node-only, and lazily so — every builtin loads through a
  dynamic import, so importing minidoc in a browser stays safe. No
  dependency: Node's own recursive `fs.watch` is the whole watcher.

## Tests

```sh
pnpm test
```

Tests are declarative YAML fixtures (`test/*.test.yaml`) driving the public
API against the in-memory filesystem: each scenario is a `source` filesystem,
optional run `options`, and either a `target` of expected outputs or the
`error` the run must reject with. Failures source-map back to the scenario's
line in the YAML file. The fixtures run through `epureVitest`; their shared
`Given` is registered in `test/steps.ts`.

`pnpm test:dev` drives `dev` and `watch` against a real filesystem and a real
socket (`test/dev.test.mjs`) — the two things the in-memory fixtures cannot
stand in for. `pnpm check` runs everything.
