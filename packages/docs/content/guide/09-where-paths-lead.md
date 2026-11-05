---
title: Where paths lead
slug: where-paths-lead
desc: Paths anchor to the layer that declares them; the Node filesystem is
  fenced to its root; any filesystem can be injected.
refs: [paths, node-fs, file-system, make-memory-file-system]
---

By now Mara's paths come from three places: the config, the frontmatter of
content files, and the `var` of `dirs` items. Each is relative to where it
is written.

### Anchored where declared

A path is relative to the layer that declares it:

- in a config, to that config's folder;
- in a frontmatter, to that content file's folder;
- in a `dirs` item's `var`, to that subfolder.

So `shared/base.yaml` can say `file: layout.html` and mean
`shared/layout.html`, whoever uses the base. Paths are templates, and
references in them only add segments after the anchor: they never move it.
A path starting with `/` is absolute and is used as written.

### The fence

Paths can come from content: a frontmatter may set `file:`. A careless or
hostile page could ask for `~/.ssh/id_rsa` and publish it. The Node
filesystem prevents that: every read, write, copy and listing must stay
inside its root, or the call fails.

Sam's site uses the shared base, which lives outside Sam's project. The
build allows that folder by name:

```js
import { nodeFs, run } from "@minidoc/core"

await run({
  fs: nodeFs(".", { allow: ["../shared"] }),
  glob: "content/config.yaml",
})
```

The check is on the path as written, with `..` collapsed. Symlinks are not
followed.

### Any filesystem

minidoc does all its reading and writing through one interface, and `run`
takes it as `fs`. Without one, it uses Node's, rooted at the current folder.
Mara's tests use the in-memory one instead:

```js
import { makeMemoryFileSystem, run } from "@minidoc/core"

const fs = makeMemoryFileSystem({
  "config.yaml": "build:\n  - output: out.html\n    input: '<p>{{`site`}}</p>'\nvar:\n  site: marmot\n",
})
await run({ fs, glob: "config.yaml" })
await fs.readFile("out.html") // "<p>marmot</p>"
```

The same interface runs minidoc in a browser, or anywhere a filesystem can
be described in seven functions.

::: story
Sam's build fails the first time: *Path outside the project root*. Sam adds
`allow: ["../shared"]`, and the error never comes back — nor can a page
reach anywhere else.
:::
