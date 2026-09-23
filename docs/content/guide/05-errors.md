---
title: Errors — fail loud, sited
slug: errors
no: M-05
tag: Errors
nav: Errors
---

Every render error is decorated with its site — the file or build entry it
came from — and undefined references in multi-line templates carry a line
number:

```
Undefined variable {{`missing`}} at line 3 in file content/intro.md
Variable cycle in file content/intro.md: intro -> intro
Undefined variable {{`missing`}} in build[0] output
```

The innermost site wins: an error is labeled once, where it happened, and not
again on the way out. Line numbers count from the top of the document — the
body keeps its place behind the frontmatter, so a custom transform reporting
"line 26" points at line 26 of the actual file.

### Inline errors for a dev server

By default any error aborts the run. With `inlineErrors: true`, content errors
instead surface as an error box (thin red border, faint red background, class
`minidoc-error`, message HTML-escaped) at their place in the output page, and
each is also logged to the console. The blast radius is the nearest content
boundary: a failing `dir` item boxes only that item, the rest of the page
still renders. Meant for a dev server — the site keeps building and the error
shows up where it happens. Output path errors still fail loud even in this
mode: a file cannot be written without a path. Leave it off in CI.

```ts
await run({ glob: "content/**/config.yaml", inlineErrors: dev })
```
