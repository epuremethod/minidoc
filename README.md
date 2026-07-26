# minidoc

A small documentation website generator. It reads a YAML config describing
variables, optional `base` config inheritance, and pages; resolves every
`{{var}}` reference to a fixpoint; and writes each page's resolved `input` to
its resolved `output` path.

```yaml
var:                      # global variables
  site: Marmot Docs
base: baseConfig.yaml     # optional: vars inherited from another config
pages:
  home:
    var:                  # page-local variables (most local scope)
      title: Home
    output: "{{lang}}/home.html"   # output paths are templates too
    input: |-
      <h1>{{site}} - {{title}}</h1>
```

Scopes, most local first: `pages.<key>.var`, then `var`, then the `base`
chain. Values may reference other variables; resolution re-substitutes until
stable. Undefined variables and reference cycles fail loud, naming the page,
the variable, and the scopes searched.

v1 is plain name substitution only — no escaping of literal `{{`/`}}`, no
filters/pipes, no expressions (future extensions).

## Usage

```sh
pnpm minidoc <configPath>
```

## Design

- `src/api/` — types only (the `FileSystem` service interface, config and
  scope types).
- `src/services/` — one file per service: `makeMemoryFileSystem` backs the
  tests, `makeNodeFileSystem` backs real runs.
- `src/features/` — pure logic (`resolve`, `parseConfig`, `run`): all I/O goes
  through the injected `FileSystem`, never direct `fs`/`path` imports.
- No classes: services are `make...()` factories returning plain objects of
  closures.

## Tests

```sh
pnpm test
```

Tests are declarative YAML fixtures (`test/*.test.yaml`): a `source` virtual
filesystem, a `target` of expected outputs (or an `error` message). The
`yaml-bdd/` Vite plugin compiles each fixture into a `describe.concurrent`
suite and source-maps failures back into the YAML file. That plugin is a
temporary resident here — it is slated for extraction into vitest-bdd — so it
depends only on minidoc's public `run` API and the in-memory FileSystem.
