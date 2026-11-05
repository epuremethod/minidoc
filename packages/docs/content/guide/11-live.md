---
title: Live
slug: live
desc: The dev server watches, rebuilds and reloads; a build script keeps
  transforms fresh; the port is drawn once and remembered.
refs: [dev, watch]
---

Running the build script after every save gets old. Mara wants to save and
see.

### dev

`dev` builds the site, watches the project, rebuilds on every change, and
serves the output with live reload:

```js
// dev.mjs
import { dev } from "@minidoc/core"

await dev({ glob: "content/**/config.yaml", build: "build.mjs" })
```

`build` is the script from the second chapter. Each rebuild runs it in a
fresh process. That matters as soon as the site has its own transforms:
they reach `run` as functions, and a running process cannot reload a module
whose file has changed. A fresh process always has the latest highlighter.

Without `build`, `dev` calls `run` itself, with `inlineErrors` on. That is
enough for a site with no transforms of its own.

### When a build breaks

Mara saves a page with a bad fence. The build fails. The page she was
reading stays in the browser, and the failure appears at its foot, in one
line: the page, the file and what is wrong. She can close it to read on. She
fixes the fence, and the next build reloads the page as before. A page she opens while the build is broken
shows the same failure.

That works because the output folder keeps the last good site. A build
script writes over the old output and never empties the folder first: `dev`
serves that folder while the script runs, and after a failed build it is
all there is. A deploy builds from a fresh checkout and never sees a stale
output.

### What gets watched

Everything under the project folder with a content, config or script
extension, except `dist`, `node_modules`, `lib` and dot-folders. Content
that lives elsewhere — Sam's shared base — is added with `watch`:

```js
await dev({
  glob: "content/config.yaml",
  build: "build.mjs",
  watch: ["../shared"],
})
```

One save makes several filesystem events; they are coalesced. A change
during a build queues exactly one more build.

### The port

A fixed port collides with every other project on the machine. So `dev`
draws a free port on first launch and writes it into the entry config:

```yaml
var:
  site: marmot
  port: 51234   # written by dev on first launch
```

The site keeps that address: it can be bookmarked, and ``{{`port`}}`` is a
var like any other. Comments and layout of the config survive the rewrite.
When the site is already running, a second `dev` prints its address and
returns. When something else holds the port, `dev` fails.

### watch

`watch` is `dev` without the server, for a project that serves its output
some other way. It returns a handle that stops it.

::: story
Mara keeps the dev server open beside the editor. She types, saves, and the
page redraws before her eyes reach it.
:::
