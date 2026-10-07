---
name: pages
slug: pages
kind: build key
summary: Fan a build entry out over a folder — one output per file.
lang: yaml
signature: |-
  - pages:
      dir: path
      glob: "*.md"          # optional
      order: asc | desc     # optional
      transform: md         # optional
      optional: true        # optional
    output: "…{{`file.stem`}}…"
    input: template         # or { file: … }
---

#### Fields

| Field | Default | Meaning |
| --- | --- | --- |
| `dir` | required | The folder, relative to the config. |
| `glob` | `*.md` | Which files. A glob with a `/` reaches into subfolders. |
| `order` | `asc` | `desc` reverses the order. |
| `transform` | from each extension | The [transform](#transform) of every file. |
| `optional` | `false` | An empty match, or a missing folder, writes nothing. |

#### What each page sees

| Name | Value |
| --- | --- |
| frontmatter names | the page's own [frontmatter](#frontmatter), over the config's vars and under the entry's `var` |
| ``{{`page`}}`` | the page's rendered body |
| ``{{`file.name`}}``, ``{{`file.stem`}}`` | its file name, with and without the extension |
| ``{{`file.dir`}}`` | the name of its parent folder |

#### Behavior

- Each page renders the entry's `input` and `output` in its own context.
- The `input` is a template or a `file`; a `copy` is an error.
- A page's frontmatter stays in that page.
- Two pages on one output path stop the build. See [output](#output).
- An empty match is an error, unless `optional: true`.
- With `inlineErrors`, a failing page renders an error box in its own output
  only.

#### Example

```yaml
build:
  - pages: { dir: candidatures, glob: "*/cv.md" }
    output: "../dist/{{`file.dir`}}-cv.html"   # dist/2026-01-acme-cv.html
    input: "{{`layouts.cv`}}"
```

Guide: [A page per file](./index.html#a-page-per-file).
