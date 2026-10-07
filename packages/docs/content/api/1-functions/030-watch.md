---
name: watch
slug: watch
kind: function
summary: Build once, then rebuild on every content, config or script change.
lang: ts
signature: |-
  function watch(options: WatchOptions): Promise<Watcher>

  type WatchOptions = RunOptions & {
    build?: string
    root?: string
    watch?: string[]
    ignore?: string[]
    extensions?: string[]
  }
---

#### Options

Every option of [`run`](#run), plus:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `build` | `string` | none | A Node script that calls `run`, spawned for each rebuild. |
| `root` | `string` | current directory | The folder watched, recursively. |
| `watch` | `string[]` | `[]` | More files or folders to watch, inside `root` or not. |
| `ignore` | `string[]` | `dist`, `node_modules`, `lib` | Path segments never watched. Dot-names are never watched either. |
| `extensions` | `string[]` | `.md`, `.yaml`, `.html`, `.css`, script files | What triggers a rebuild. |

#### Behavior

- With `build`, each rebuild runs that script in a fresh process, so edited
  transforms take effect.
- Without `build`, `run` is called in this process with `inlineErrors` on. It
  cannot see an edited transform: transforms are functions, and a running
  process cannot reload a changed module.
- New files under `root` trigger a rebuild too.
- Events are coalesced. A change during a build queues exactly one more build.
- Building in-process, the `watch` folders are allowed by the Node filesystem's
  fence. A `build` script passes its own `allow`.
- Node only. Node's recursive `fs.watch` is the whole watcher.

#### Returns

A [`Watcher`](#watcher): `stop()`.

#### Example

```js
import { watch } from "@epure/minidoc"

const watcher = await watch({ glob: "content/**/config.yaml", build: "src/build.mjs" })
// later
watcher.stop()
```

Guide: [Live](./index.html#live).
