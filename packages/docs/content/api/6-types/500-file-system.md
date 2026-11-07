---
name: FileSystem
slug: file-system
kind: type
summary: The one interface minidoc reads and writes through.
lang: ts
signature: |-
  interface FileSystem {
    readFile(path: string): Promise<string>
    writeFile(path: string, content: string): Promise<void>
    copy(source: string, output: string): Promise<void>
    exists(path: string): Promise<boolean>
    glob(pattern: string): Promise<string[]>
    listFiles(dir: string): Promise<string[]>
    listDirs(dir: string): Promise<string[]>
  }
---

#### Methods

| Method | Returns |
| --- | --- |
| `readFile` | the file's text |
| `writeFile` | once the file is written |
| `copy` | once a file, or a folder recursively, is copied without being read |
| `exists` | whether the path exists |
| `glob` | plain files matching `pattern`, sorted by name; relative patterns give root-relative paths |
| `listFiles` | the names of the plain files directly inside `dir`, sorted; `[]` if it does not exist |
| `listDirs` | the names of the folders directly inside `dir`, sorted; `[]` if it does not exist |

#### Behavior

- minidoc never imports `node:fs`: every read and write goes through the
  filesystem given to [`run`](#run).
- `listDirs` serves `dirs` vars and globs holding a `/`.
- Two implementations ship: [`nodeFs`](#node-fs) and
  [`makeMemoryFileSystem`](#make-memory-file-system).

#### Example

```ts
import type { FileSystem } from "@epure/minidoc"

// Read-only content from a map, writes collected for the caller.
const written: Record<string, string> = {}
const fs: FileSystem = {
  readFile: async (path) => files[path],
  writeFile: async (path, content) => { written[path] = content },
  // … copy, exists, glob, listFiles, listDirs
}
```

Guide: [Where paths lead](./index.html#where-paths-lead).
