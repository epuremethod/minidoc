---
title: Braces on the page
slug: braces-on-the-page
desc: Backtick-quote a reference to print it as text — for documenting
  template languages, minidoc's own included.
refs: [escape, reference]
---

`marmot` formats dates with patterns, and Mara's CI writes the commit into
the footer with a GitHub expression: ``${{ `github.sha` }}``. Both need double
braces on the page. minidoc would try to render them.

### The escape

Quote the name in backticks, and the reference is printed as text instead
of rendered: `{{&#96;title&#96;}}` writes ``{{`title`}}``. The name needs no
var. Only the two backticks are removed, so spacing stays as written:
`${{ &#96;github.sha&#96; }}` writes ``${{ `github.sha` }}``.

```yaml
# .github/workflows/deploy.yml, documented on Mara's site
- run: echo "built from ${{ `github.sha` }}"
```

### It stays text

An escape is undone exactly once, where it is written. What comes out is
text, not a template: it stays as it is when another var includes it, when
a `dir` renders it, when a transform passes it on. minidoc never renders a
result twice.

This page is built that way: every reference you see in its examples is an
escape in its source.

::: story
Mara documents `marmot`'s pattern syntax in a chapter full of braces. None
of them are rendered by accident, and none of them needed a special file.
:::
