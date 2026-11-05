---
title: One page
slug: one-page
desc: Install minidoc, write a layout, a config and a build script, and get
  one page out.
refs: [config, reference, build, copy, run]
---

Mara starts where every site starts: one page, on screen, with the right
title.

```sh
pnpm add -D @minidoc/core
```

### The layout

The layout is plain HTML. Where content will go, it holds a reference: a
name between double braces.

```html
<!-- content/layout.html -->
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>{{`title`}}</title>
    <link rel="stylesheet" href="styles.css">
  </head>
  <body>
    <main>
      {{`main`}}
    </main>
  </body>
</html>
```

### The config

The config says what the references mean and which files to write. Under
`var` go the templates; under `build`, the outputs.

```yaml
# content/config.yaml
var:
  site: Marmot
  layout:
    file: layout.html
build:
  - output: ../dist/index.html
    input: "{{`layout`}}"
    var:
      title: "{{`site`}} — dates, small"
      main: "<h1>{{`site`}}</h1>"
  - output: ../dist/styles.css
    input: { copy: styles.css }
```

The first build entry renders `layout` and writes the result to
`dist/index.html`. Its own `var` gives `title` and `main` for this page only.
The second copies the stylesheet as it is: a `copy` input is never read or
rendered.

Paths in a config are relative to the config's folder, so `../dist` is a
folder next to `content`.

### The build script

```js
// build.mjs
import { run } from "@minidoc/core"

await run({ glob: "content/**/config.yaml" })
```

`run` finds every config the glob matches and builds them. `node build.mjs`
writes the two files.

::: story
Mara opens `dist/index.html`. The tab reads *Marmot — dates, small*. She
changes `site` to `marmot`, runs the script again, and both the tab and the
heading follow.
:::

### What happened

`title` is itself a template: ``"{{`site`}} — dates, small"``. When the
layout asked for ``{{`title`}}``, minidoc rendered that template, which asked
for ``{{`site`}}``, which it found one level up, in the config's `var`.
References resolve as deep as they need to, and only when something asks
for them.

A name that is not defined anywhere stops the build with the name and the
file it was asked from. There are no defaults and no empty strings by
accident.
