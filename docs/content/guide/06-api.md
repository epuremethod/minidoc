---
title: run, transforms, filesystems
slug: api
no: M-06
tag: API
nav: API
---

```ts
import { run } from "@epure/minidoc"
import { apiMd, typescript } from "./transforms.ts"

await run({
  glob: "content/**/config.yaml",
  transform: { apiMd, typescript },
})
```

Custom transforms — plain `(text: string) => string` functions — extend or
override the built-in registry (`md` renders markdown via marked, `none`
passes through). The YAML coloring on this page is one: the site's build
overrides `md` with a marked renderer that tokenizes fenced yaml blocks.

### Filesystems

All I/O goes through one injected `FileSystem` interface — the only door to
the outside world. Inject one for a browser, test, or other non-Node
environment; the Node adapter loads lazily only when `fs` is omitted:

```ts
import { run, nodeFs, makeMemoryFileSystem } from "@epure/minidoc"

await run({ fs: makeMemoryFileSystem(files), glob: "**/config.yaml" })
await run({ fs: nodeFs(new URL("./content/", import.meta.url)), glob: "**/config.yaml" })
```

### Design

Three source files, ReScript, plus the dev runner:

- `src/Schema.res` — [Sury](https://github.com/DZakh/sury) schemas parsing
  YAML configs and frontmatter into tagged variants; path anchoring, and the
  remembered port.
- `src/Minidoc.res` — contexts ([tilia](https://tiliajs.dev) carves),
  rendering, the filesystems, `run`. All I/O goes through the injected
  filesystem; transforms are injected too.
- `src/Minidoc.resi` — the public interface, mirrored by the hand-written
  `src/Minidoc.res.d.mts` for TypeScript consumers.
- `src/Dev.res` — `watch` and `dev`: the watcher, the rebuild loop, the
  static server. Node-only, and lazily so — every builtin loads through a
  dynamic import, so importing minidoc in a browser stays safe. No
  dependency: Node's own recursive `fs.watch` is the whole watcher.
