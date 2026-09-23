---
title: Watch, rebuild, live reload
slug: dev
no: M-07
tag: Development
nav: Dev
desc: The dev and watch runners — watch, rebuild in a fresh process, serve
  with live reload — and the remembered port.
---

`dev` builds the site, watches the project, rebuilds what changed, and serves
the output with live reload:

```ts
// src/dev.mjs
import { dev } from "@epure/minidoc"

await dev({ glob: "content/**/config.yaml", build: "src/build.mjs" })
```

A rebuild fires on any `.md`, `.yaml`, `.html`, `.css` or script file under
the root — new files included. `dist`, `node_modules`, `lib` and every
dot-name go unwatched, so a build never triggers itself. One save is several
filesystem events, so changes coalesce; a change arriving mid-build queues
exactly one more run, however many arrive.

`build` names the script that calls `run()`, and each rebuild runs it in a
**fresh process**. That is what makes an edited transformer take effect:
transforms reach `run` as closures, and no ESM cache hands back a module a
file has changed under. Without `build`, `dev` calls `run` in its own process
with `inlineErrors` on — fine for a site with no custom transforms, blind to
a transformer edit.

`root` (default: the current directory) is what gets watched, `serve`
(default `dist`) is what gets served, and `ignore` and `extensions` replace
the two lists above. `watch` adds paths — files or folders, inside the
project or not — for content that lives elsewhere:

```ts
await dev({
  glob: "content/**/config.yaml",
  build: "src/build.mjs",
  watch: ["../docs", "../db/types.yaml"],
})
```

The served page carries one injected line, an `EventSource` that reloads it
when a build lands. The rest is a static host: `/guide/` answers with its
index, `/guide` with `guide.html` then `guide/index.html`, so the dev site is
the deployed site.

`watch` is the same runner without the server, for a project that serves its
output some other way:

```ts
const watcher = await watch({ glob: "content/**/config.yaml", build: "src/build.mjs" })
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

The site keeps that address for good: bookmarkable, and ``{{`port`}}`` is an
ordinary var a template can print. The config is rewritten through yaml's
document API, so comments and layout survive. The day that port is taken, a
free one replaces it in the file. Passing `port` explicitly skips all of
this and writes nothing.
