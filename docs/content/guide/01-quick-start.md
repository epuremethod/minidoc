---
title: One config, one site
slug: quick-start
no: M-01
tag: Getting started
nav: Start
desc: The advised workflow when starting a new documentation website —
  design, install, agent-written sources, dev server. Then a base
  index.html layout, one config, one site — every declared output is
  rendered and written.
---

### Starting a documentation website

1. **Design.** Find a design, or vibe-code one. The look is yours — HTML,
   CSS, fonts. minidoc fills in the content. Start from a base `index.html`
   layout — one HTML shell, shared by every page.
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

The base layout, its config, and a `run`:

```html
<!-- content/layout.html — the base index.html layout -->
<!doctype html>
<html lang="{{`lang`}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{`title`}}</title>
<link rel="stylesheet" href="styles.css">
</head>
<body>
<main>{{`main`}}</main>
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
    input: "{{`layout`}}"
    var:
      title: "{{`site`}}"
      main: "<h1>{{`site`}}</h1>"
  - output: styles.css
    input: { copy: styles.css }
```

```ts
// build.mjs
import { run } from "@epure/minidoc"

await run({ glob: "content/**/config.yaml" })
```

This site is the worked example — layout, pages, config, `run`, and dev
server in
[the docs source](https://github.com/epuremethod/minidoc/tree/main/docs).

minidoc discovers YAML configs by glob. Each config declares variables and
build outputs; every ``{{`var`}}`` reference is rendered and each resolved
`input` is written to its `output` path.

Runs update declared outputs in place and never clean old output first, so a
live server keeps serving the previous files until replacements are written.

`base` inherits templates from another config — see [Model](#model). `file`,
`dir`, `list`, and `value` vars grow the site out of content files — see
[Vars](#vars).
