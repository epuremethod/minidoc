---
title: One config, one site
slug: quick-start
no: M-02
tag: First build
nav: Start
desc: Install @epure/minidoc, point run at a glob of YAML configs, and every
  declared output is rendered and written.
---

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
