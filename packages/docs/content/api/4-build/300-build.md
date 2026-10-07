---
name: build
slug: build
kind: config key
summary: The list of outputs a config writes — each an output path and an input.
lang: yaml
signature: |-
  build:
    - output: path            # a template
      input: template         # or { file: … }, { dir: … }, { copy: … }
      var: { … }              # optional
      pages: { dir: path }    # optional, see pages
---

#### Fields

| Field | Default | Meaning |
| --- | --- | --- |
| `output` | required | Where the result is written. A template, relative to the config. |
| `input` | required | What is written: a template, a `file` or `dir` mapping, or a [`copy`](#copy). |
| `var` | none | Vars of this entry: the build layer, over the config's. |
| `pages` | none | One output per file of a folder. See [`pages`](#pages). |

#### Inputs

| Input | Written |
| --- | --- |
| a string | the template, rendered |
| `{ file: path, transform? }` | the file, rendered as a [`file`](#file) var; its frontmatter is the entry's least local layer |
| `{ dir: path, each, … }` | the folder, rendered as a [`dir`](#dir) var |
| `{ copy: path }` | the file or folder, copied unread |

`optional` and `template` belong to file vars and are an error on a file input.

#### Behavior

- `output` may use any var of the entry's context, a file input's frontmatter
  included.
- Every output path resolves before anything is written. See [output](#output).
- Errors from an entry are labelled `build[0]`, `build[1]`, … in order.

#### Example

```yaml
build:
  - output: "../dist/{{`slug`}}.html"
    input:
      file: home.md
  - output: ../dist/guide.html
    input: "{{`layout`}}"
    var:
      main: "{{`chapters`}}"
```

Guide: [One page](./index.html#one-page).
