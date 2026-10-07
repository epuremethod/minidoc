---
name: list
slug: list
kind: var kind
summary: Render a list of scalars through one template, join them, and wrap them.
lang: yaml
signature: |-
  name:
    list: var-name
    each: "…{{`item`}}…"
    join: ""                  # optional
    template: "…{{`body`}}…"  # optional
---

#### Fields

| Field | Default | Meaning |
| --- | --- | --- |
| `list` | required | The name of a var holding a list of scalars, from a config or a frontmatter. |
| `each` | required | The template of one element, given as ``{{`item`}}``. |
| `join` | nothing | What sits between elements. |
| `template` | none | Wraps the joined elements, given as ``{{`body`}}``. |

#### Behavior

- The list is looked up in the context the var renders in. Declared once in a
  config, it reads the list of each `dir` item or page it renders for.
- An empty list renders nothing, `template` included.

#### Example

```yaml
var:
  seeAlsoLinks:
    list: seeAlso
    each: '<a href="#{{`item`}}">{{`item`}}</a>'
    join: ", "
    template: "<p>See also: {{`body`}}</p>"
```

Guide: [A reference](./index.html#a-reference).
