---
name: "{{`name`}}"
slug: reference
kind: syntax
summary: A reference renders the var of that name, looked up in the nearest context.
lang: txt
signature: |-
  {{`name`}}
  {{`group.key`}}
  {{ `name` }}
---

#### Syntax

- Two braces, optional spaces, a name, optional spaces, two braces.
- A name starts with a letter or `_`, then letters, digits, `_`, `-` or `.`.
- A `.` reads into a group: ``{{`intro.title`}}`` is the `title` of `intro`.

#### Behavior

- The name is looked up in the context the template renders in: the nearest
  layer that defines it wins.
- A reference renders its var's template, which may hold references of its
  own. Each var renders once per context and is cached.
- Plain lookup only: no filters, no expressions, no defaults.
- An undefined name is an error, with the name and where it was asked from.
- A cycle (`a` needs `b` needs `a`) is an error naming the cycle.
- Reading a group whole, rather than one of its keys, is an error — unless the
  group is a [var kind](#var).
- A rendered result is text and is never rendered again.
- To print a reference as text, see [escape](#escape).

#### Example

```yaml
var:
  site: marmot
  title: "{{`site`}} — dates, small"   # renders to "marmot — dates, small"
```

Guide: [One page](./index.html#one-page).
