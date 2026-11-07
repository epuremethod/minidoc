---
name: nodeFs
slug: node-fs
kind: function
summary: The Node filesystem, fenced to its root and the folders it allows.
lang: ts
signature: |-
  function nodeFs(root?: string | URL, options?: FsOptions): FileSystem

  type FsOptions = { allow?: string[] }
---

#### Parameters

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `root` | `string \| URL` | current directory | A path or a `file://` URL. Relative paths in calls resolve against it. |
| `options.allow` | `string[]` | `[]` | Folders outside the root that may be read and written too, relative to the root or absolute. |

#### Behavior

- Every read, write, copy and listing must stay inside the root or an
  `allow` folder, or the call fails with *Path outside the project root*.
- The check is on the path as written, with `..` collapsed. Symlinks are not
  followed.
- `writeFile` creates missing parent folders.
- `copy` copies a file, or a folder recursively.
- `listFiles` and `listDirs` return `[]` for a folder that does not exist.

#### Why a fence

Paths are templates, and content can set them: a frontmatter may say `file:`.
The fence keeps a page from publishing a file outside the project, or writing
one.

#### Example

```js
import { nodeFs, run } from "@epure/minidoc"

const root = new URL("./", import.meta.url)
await run({ fs: nodeFs(root, { allow: ["../shared"] }), glob: "content/config.yaml" })
```

Guide: [Where paths lead](./index.html#where-paths-lead).
