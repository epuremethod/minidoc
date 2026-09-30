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

A custom filesystem implements `readFile`, `writeFile`, `copy`, `exists`,
`glob`, `listFiles` and `listDirs` — the last lists the subfolders a `dirs`
var or a subfolder glob walks.

The Node filesystem is fenced: every read, write, copy and listing must stay
inside its root, or the call fails loud. Paths are templates that content can
steer — a page's frontmatter may set `file:` — so the fence is what keeps a
page from publishing `~/.ssh/id_rsa` or writing outside the project. Folders
outside the root that the site really uses are allowed explicitly:

```ts
await run({ fs: nodeFs(root, { allow: ["../shared-content"] }), glob: "config.yaml" })
```

`allow` entries are relative to the root or absolute. The check is on the
path as written (`..` collapsed); symlinks are not followed. `watch` and `dev`
building in-process allow their `watch` folders; a `build` script passes its
own `allow`.

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
