---
title: One config, one site
slug: quick-start
no: M-01
tag: Getting started
nav: Start
desc: The advised workflow when starting a new documentation website —
  design, install, agent-written sources, dev server. Then one config,
  one site — every declared output is rendered and written.
---

### Starting a documentation website

1. **Design.** Find a design, or vibe-code one. The look is yours — HTML,
   CSS, fonts. minidoc fills in the content.
2. **Install.** Add `@epure/minidoc`, write a config and a `run`, as below.
3. **Ask an agent to write the docs.** At minimum give it the list of pages
   you want, and how the markdown sources should be organised — one file
   per concept, one file per method, one file per chapter. Fix the shape
   first; the agent fills the files.
4. **Dev server.** `dev()` watches, rebuilds, and live-reloads — see
   [Dev](#dev) — and the site takes shape as the files land.

```sh
pnpm add -D @epure/minidoc
```

```yaml
# content/config.yaml
var:
  site: Marmot Docs
  lang: en
build:
  - output: "{{`lang`}}/home.html"   # output paths are templates too
    input: |-
      <h1>{{`site`}}</h1>
```

```ts
// build.mjs
import { run } from "@epure/minidoc"

await run({ glob: "content/**/config.yaml" })
```

minidoc discovers YAML configs by glob. Each config declares variables and
build outputs; every ``{{`var`}}`` reference is rendered and each resolved
`input` is written to its `output` path.

Runs update declared outputs in place and never clean old output first, so a
live server keeps serving the previous files until replacements are written.

`base` inherits templates from another config — see [Model](#model). `file`,
`dir`, `list`, and `value` vars grow the site out of content files — see
[Vars](#vars).
