---
name: file
slug: file
kind: var kind
summary: Load a template from a content file, with its frontmatter.
lang: yaml
signature: |-
  name:
    file: path
    transform: md | none | your own   # optional
    optional: true                    # optional
    template: "…{{`body`}}…"          # optional
---

#### Fields

| Field | Default | Meaning |
| --- | --- | --- |
| `file` | required | The file, relative to the declaring layer. |
| `transform` | from the extension | The [transform](#transform) applied after references render. |
| `optional` | `false` | A missing file renders as an empty string. |
| `template` | none | Wraps the rendered file, given as ``{{`body`}}``, in the file's context. |

#### Transform inference

| Extension | Transform |
| --- | --- |
| `.md`, `.markdown` | `md` |
| `.html`, `.htm` | `none` |
| anything else | an error, unless `transform` is given |

#### Behavior

- References in the file render first, in the file's context; then the
  transform runs on the result.
- The file's [frontmatter](#frontmatter) is the innermost layer of its
  context, and the declaring context reads it under the var's name:
  ``{{`intro.title`}}``.
- A missing file is an error, unless `optional: true`. A missing optional file
  exports no frontmatter.
- `template` renders nothing when the body is empty: a missing optional file,
  or one holding only frontmatter or whitespace.
- The file loads when a render first needs it, once.

#### Example

```yaml
var:
  intro:
    file: intro.md
  banner:
    file: banner.md
    optional: true
    template: "<aside class='banner'>{{`body`}}</aside>"
```

Guide: [Words in files](./index.html#words-in-files).
