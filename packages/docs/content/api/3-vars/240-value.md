---
name: value
slug: value
kind: var kind
summary: Render an inline template, then pass it through a named transform.
lang: yaml
signature: |-
  name:
    value: "…{{`name`}}…"
    transform: name
---

#### Fields

| Field | Default | Meaning |
| --- | --- | --- |
| `value` | required | The template. |
| `transform` | required | The [transform](#transform) applied to the rendered template. |

#### Behavior

- Renders in the context it is read from, like any template. Declared once in
  a config and read inside a `dir`'s `each`, it renders once per item, with
  that item's frontmatter.
- A `value` without `transform` is an error.

#### Example

```yaml
var:
  signatureHtml:
    value: "{{`signature`}}"
    transform: typescript
  entries:
    dir: api
    each: "<article>{{`signatureHtml`}}{{`body`}}</article>"
```

Guide: [A reference](./index.html#a-reference).
