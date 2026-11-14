---
name: makeMemoryFileSystem
slug: make-memory-file-system
kind: function
summary: A filesystem held in memory, seeded from a map of paths to contents.
lang: ts
signature: |-
  function makeMemoryFileSystem(seed?: Record<string, string>): FileSystem
---

#### Parameters

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `seed` | `Record<string, string>` | `{}` | File paths and their contents. Folders exist where files do. |

#### Behavior

- Implements every method of [`FileSystem`](#file-system) over the map.
- Written files can be read back with `readFile`.
- Nothing touches the disk. Meant for tests, and for running minidoc where
  there is no disk.

#### Example

```js
import { makeMemoryFileSystem, run } from "@minidoc/core"

const fs = makeMemoryFileSystem({
  "config.yaml": "var:\n  site: marmot\nbuild:\n  - output: out.html\n    input: '<p>{{`site`}}</p>'\n",
})
await run({ fs, glob: "config.yaml" })
await fs.readFile("out.html") // "<p>marmot</p>"
```

Guide: [Where paths lead](./index.html#where-paths-lead).
