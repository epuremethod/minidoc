---
name: output
slug: output
kind: rule
summary: Outputs are planned before any is written, and written in place.
lang: txt
signature: |-
  Output path collision: dist/same.html is written by both build[0] (page cvs/a.md) and build[0] (page cvs/b.md)
---

#### Behavior

- Every output path of a config resolves before the first file is written.
  A path that cannot resolve stops the build, even with `inlineErrors`.
- Two outputs resolving to the same path stop the build, naming both.
- Copies into one folder merge and are exempt.
- Outputs are written over the previous ones. The output folder is never
  emptied first, so a server keeps serving the old files until the new ones
  land.
- A file whose source was deleted keeps its old output. A build that wants a
  clean folder removes it before calling [`run`](#run).

#### Example

```js
import { rm } from "node:fs/promises"
import { run } from "@minidoc/core"

await rm("dist", { recursive: true, force: true })
await run({ glob: "content/**/config.yaml" })
```

Guide: [A page per file](./index.html#a-page-per-file).
