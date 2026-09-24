---
title: Contexts — dictionaries of templates
slug: model
no: M-01
tag: The model
nav: Model
desc: Contexts merge and you inherit formulas, not values. How references
  render and how to escape one.
---

One idea drives everything:

> A **context** is a dictionary of templates. A child context is the parent's
> templates merged with its own — own wins. Everything renders in its nearest
> context.

A `base` config, the config's `var`, a build's `var`, a content file's
frontmatter: each is one layer, merged into the next context. Precedence is
merge order.

**You inherit formulas, not values.** A base declaring
`layout: "<h1>{{`title`}}</h1>"` does not hand you a rendered string — the
template becomes yours and resolves against your `title`, like copying a
spreadsheet: the formulas come along and recompute against your cells.

```yaml
# baseConfig.yaml
var:
  layout: "<h1>{{`title`}}</h1>"
```

```yaml
# config.yaml
base: baseConfig.yaml
build:
  - var: { title: Home }
    output: home.html
    input: "{{`layout`}}"        # -> <h1>Home</h1>
```

Substitution is plain name lookup — no filters, no expressions. Undefined
names and reference cycles [fail loud, sited](#errors).

### Escaping a reference

To emit a reference as literal text, backtick-quote the name:
<code>&#123;&#123;&#96;name&#96;&#125;&#125;</code> outputs `{{`name`}}` without
evaluation, and the name needs no var. Only the quotes are removed, so the
spacing you wrote survives — <code>$&#123;&#123; &#96;github.sha&#96; &#125;&#125;</code>
outputs ``${{ `github.sha` }}``, which is what makes the escape usable for
documenting templating languages of your own.

What comes out is text, not a template: the literal stays literal however far
it travels — through an outer var, a file var importing another, a `dir` or
`list` item, a transform. A rendered result is never re-rendered, so an
escape unwraps exactly once, where it was written.

### Under the hood

Each context is a [tilia](https://tiliajs.dev) carve: every var is a lazy,
cached, dependency-tracked computed. Fittingly, tilia's own documentation is
built with minidoc.
