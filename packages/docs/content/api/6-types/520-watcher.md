---
name: Watcher, Server
slug: watcher
kind: type
summary: The handles watch and dev return.
lang: ts
signature: |-
  interface Watcher {
    stop(): void
  }

  interface Server extends Watcher {
    port: number
  }
---

#### Members

| Member | Of | Meaning |
| --- | --- | --- |
| `stop()` | both | Stops watching; a `Server` also stops serving. |
| `port` | `Server` | The port the dev server listens on. |

#### Behavior

- [`watch`](#watch) returns a `Watcher`, [`dev`](#dev) a `Server`.
- After `stop()`, no rebuild starts.

#### Example

```js
import { dev } from "@minidoc/core"

const server = await dev({ glob: "content/config.yaml", build: "src/build.mjs" })
console.log(`http://127.0.0.1:${server.port}`)
```

Guide: [Live](./index.html#live).
