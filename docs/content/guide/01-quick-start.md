---
title: One config, one site
slug: quick-start
no: M-01
tag: First build
nav: Start
desc: Install @epure/minidoc, point run at a glob of YAML configs, and every
  declared output is rendered and written.
---

Install the package, point `run` at a config, done:

```sh
pnpm add -D @epure/minidoc
```

minidoc discovers YAML configs by glob; each config declares variables and
build outputs. Every ``{{`var`}}`` reference is rendered and each resolved
`input` is written to its `output` path.

```yaml
var:                      # this config's context
  site: Marmot Docs
base: baseConfig.yaml     # optional: templates inherited from another config
build:
  - var:                  # each build extends the context
      title: Home
    output: "{{`lang`}}/home.html"   # output paths are templates too
    input: |-
      <h1>{{`site`}} - {{`title`}}</h1>
```

And a build script is three lines:

```ts
import { run } from "@epure/minidoc"

await run({ glob: "content/**/config.yaml" })
```

Runs update declared outputs in place and never clean old output first, so a
live server keeps serving the previous files until replacements are written.
