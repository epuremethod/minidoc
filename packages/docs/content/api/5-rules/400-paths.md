---
name: paths
slug: paths
kind: rule
summary: A path is relative to the layer that declares it, and is a template.
lang: yaml
signature: |-
  base | output | file | dir | dirs | pages.dir | copy
---

#### Anchors

| Declared in | Relative to |
| --- | --- |
| a config, or a base config | that config's folder |
| a frontmatter | that content file's folder |
| a `dirs` item's `var` | that subfolder |

#### Behavior

- A path is a template: it may use any var, a page's frontmatter, or another
  file's frontmatter.
- References only add segments after the anchor; they never move it.
- A path written starting with `/` is absolute and used as written.
- Paths are posix-style, with `/`.
- Where a path may lead is the filesystem's business: [`nodeFs`](#node-fs)
  stays inside its root and its `allow` folders.

#### Example

```yaml
# shared/base.yaml
var:
  layout:
    file: layout.html   # shared/layout.html, whoever inherits it
```

Guide: [Where paths lead](./index.html#where-paths-lead).
