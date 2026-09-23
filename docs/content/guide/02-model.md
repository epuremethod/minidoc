---
title: Contexts — dictionaries of templates
slug: model
no: M-02
tag: The model
nav: Model
---

One idea drives everything:

> A **context** is a dictionary of templates. A child context is the parent's
> templates merged with its own — own wins. Everything renders in its nearest
> context.

So a `base` config, the config's `var`, a build's `var`, a content file's
frontmatter: each is just a layer merged into the next context. Precedence is
merge order, nothing more.

The one sentence worth memorizing: **you inherit formulas, not values.** A
base declaring `layout: "<h1>{{`title`}}</h1>"` doesn't hand you a rendered
string — the template becomes *yours* and resolves against *your* `title`,
like copying a spreadsheet: you copy the formulas, and they recompute against
your cells.

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

Undefined variables and reference cycles fail loud, naming the build entry
and the variable path — plus the line, for multi-line templates (see
[Errors](#errors)). Plain name substitution — no filters, no expressions.

### Escaping a reference

To render a reference as literal text, backtick-quote the name:
<code>&#123;&#123;&#96;name&#96;&#125;&#125;</code> outputs `{{`name`}}` without
evaluation, and the name needs no var. Only the quotes are removed, so the
spacing you wrote survives — <code>$&#123;&#123; &#96;github.sha&#96; &#125;&#125;</code>
outputs ``${{ `github.sha` }}``, which is what makes the escape usable for
documenting templating languages of your own.

What comes out is text, not a template: the literal stays literal however far
it travels — through an outer var, a file var importing another, a `dir` or
`list` item, a transform. A rendered result is never re-rendered, so an escape
unwraps exactly once, where it was written. Every example on this page is
written that way — this site is a minidoc build, and these code blocks live
inside its templates.

### Under the hood

Each context is a [tilia](https://tiliajs.dev) carve: every var is a lazy,
cached, dependency-tracked computed. Fittingly, tilia's own documentation is
built with minidoc — and so is this page: tilia all the way down.
