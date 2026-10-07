---
name: dirs
slug: dirs
kind: var kind
summary: Render one item per subfolder, each with vars loaded in that subfolder.
lang: yaml
signature: |-
  name:
    dirs: path
    each: "…{{`folder.name`}}…"
    var:                  # optional, loaded in each subfolder
      readme: { file: readme.md }
    order: asc | desc     # optional
    join: "\n"            # optional
    optional: true        # optional
---

#### Fields

| Field | Default | Meaning |
| --- | --- | --- |
| `dirs` | required | The folder whose subfolders are iterated, relative to the declaring layer. |
| `each` | required | The template of one item. |
| `var` | none | Vars of each item. Their paths are relative to the subfolder. |
| `order` | `asc` | `desc` reverses the order. |
| `join` | a newline | What sits between items. |
| `optional` | `false` | An empty or missing folder renders nothing. |

#### What `each` sees

| Name | Value |
| --- | --- |
| ``{{`folder.name`}}`` | the subfolder's name, also usable in the item's paths |
| the item's `var` | each var; a file var's frontmatter under its name: ``{{`readme.title`}}`` |

#### Behavior

- Subfolders are listed in name order. Files directly in the folder are
  ignored.
- The item's `var` is the item's innermost layer, over the declaring context.
- What an item loads stays in that item.
- A missing file in a subfolder is an error naming the folder, unless that
  var is `optional`.
- An empty or missing folder is an error, unless `optional: true`.
- With `inlineErrors`, a failing item renders as an error box and the others
  render.

#### Example

```yaml
var:
  examples:
    dirs: examples
    order: desc
    each: "<section id='{{`folder.name`}}'>{{`readme`}}{{`code`}}</section>"
    var:
      readme: { file: readme.md }
      code: { file: example.ts, transform: typescript, optional: true }
```

Guide: [Folders of folders](./index.html#folders-of-folders).
