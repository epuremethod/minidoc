---
name: frontmatter
slug: frontmatter
kind: file block
summary: A YAML block at the top of a content file — the most local layer.
lang: md
signature: |-
  ---
  title: Install
  tags: [setup, npm]
  meta:
    order: 1
  ---

  The body.
---

#### Behavior

- Opens with `---` on the first line and closes with the next `---` line.
- Holds scalars, lists and groups, like a config's `var`, and may declare var
  kinds too. Its paths are relative to the content file's folder.
- The body renders in a context whose innermost layer is the frontmatter.
- Line numbers in errors count from the top of the file, frontmatter included.

#### Who sees it

| Loaded by | The frontmatter is read |
| --- | --- |
| a [`file`](#file) var | inside the file, and by the config under the var's name: ``{{`intro.title`}}`` |
| a `file` build input | as the build's least local layer, usable in its output path |
| a [`dir`](#dir) item | inside that item only |
| a [`dirs`](#dirs) item's file | inside that item, under the file var's name |
| a [`pages`](#pages) page | inside that page, usable in its output path |

#### Example

```md
---
title: Install
slug: install
---

Run `pnpm add marmot`.
```

Guide: [Words in files](./index.html#words-in-files).
