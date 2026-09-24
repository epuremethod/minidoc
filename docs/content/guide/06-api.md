---
title: run, transforms, filesystems
slug: api
no: M-06
tag: API
nav: API
desc: The run API, custom text transforms, injectable filesystems, and the
  source layout.
---

```ts
import { run } from "@epure/minidoc"
import { apiMd, typescript } from "./transforms.ts"

await run({
  glob: "content/**/config.yaml",
  transform: { apiMd, typescript },
})
```

Options:

- `glob` — required; selects the entry configs.
- `fs` — the [filesystem](#filesystems); defaults lazily to Node's, rooted at
  the current directory.
- `transform` — named transforms added to or overriding the built-ins.
- `inlineErrors` — content errors render in place instead of aborting (see
  [Errors](#errors)).

Custom transforms are plain `(text: string) => string` functions. The
built-in registry has `md` (markdown via marked) and `none` (passthrough) —
this site's build overrides `md` to color fenced YAML.

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
