---
title: A reference
slug: a-reference
desc: An API reference from one file per function — list vars for links,
  value vars and custom transforms for signatures.
refs: [list, value, transform, run]
---

The reference has a different job from the guide. Nobody reads it in order:
people search it, land on one function and leave. Mara cuts it as one file
per function, each with the same frontmatter.

```md
<!-- content/api/parse.md -->
---
name: parse
slug: parse
signature: "parse(text: string): Date"
seeAlso: [format, isValid]
---

Reads an ISO 8601 date. Fails on anything else.
```

A `dir` var renders the folder, as in the guide. Two more var kinds handle
what is left: the links, and the signature.

### A list var

`seeAlso` is a list. A `list` var renders each item through `each`, joins
them, and wraps the result:

```yaml
var:
  seeAlsoLinks:
    list: seeAlso
    each: '<a href="#{{`item`}}">{{`item`}}</a>'
    join: ", "
    template: "<p>See also: {{`body`}}</p>"
```

``{{`item`}}`` is one element. An empty list renders nothing, wrapper
included, so an entry without `seeAlso` has no empty *See also*.

### A value var

The signature should be colored like code. A `value` var renders a template
and passes the result through a transform:

```yaml
var:
  signatureHtml:
    value: "{{`signature`}}"
    transform: typescript
  entries:
    dir: api
    each: |-
      <article id="{{`slug`}}">
        <h2>{{`name`}}</h2>
        {{`signatureHtml`}}
        {{`body`}}
        {{`seeAlsoLinks`}}
      </article>
```

`signatureHtml` and `seeAlsoLinks` are declared once, in the config. They
render inside `each`, so ``{{`signature`}}`` and `seeAlso` are those of the
entry being rendered. This is the second chapter's rule again: the config
holds the formula, each entry supplies the values.

### Your own transforms

`typescript` is not built in. A transform is a function from text to text,
given to `run` by name:

```js
// build.mjs
import { run } from "@epure/minidoc"
import { typescript } from "./highlight.mjs"

await run({ glob: "content/**/config.yaml", transform: { typescript } })
```

The built-in transforms are `md` and `none`. A transform named `md`
replaces the built-in one for every markdown file — this site does that to
color its code.

::: story
Mara adds `format.md`. It appears in the reference, and `parse`'s *See
also* link to it starts working.
:::
