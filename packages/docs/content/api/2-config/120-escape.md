---
name: "{{&#96;name&#96;}}"
slug: escape
kind: syntax
summary: A backtick-quoted name prints the reference as text, unrendered.
lang: txt
signature: |-
  {{&#96;name&#96;}}      →  {{`name`}}
  ${{ &#96;github.sha&#96; }}  →  ${{ `github.sha` }}
---

#### Behavior

- The two backticks are removed; everything else stays as written, spaces
  included.
- The name needs no var.
- The escape is undone exactly once, where it is written. The result is text:
  it stays text through outer vars, file vars, `dir` and `list` items and
  transforms.
- A name can never contain a backtick, so there is no escape for an escape.

#### Example

```md
The footer shows the commit: `${{ `github.sha` }}`.
```

In the source of that line, the reference is written with backticks around
`github.sha`.

Guide: [Braces on the page](./index.html#braces-on-the-page).
