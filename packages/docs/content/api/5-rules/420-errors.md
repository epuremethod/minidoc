---
name: errors
slug: errors
kind: rule
summary: Errors stop the build and name where they happened — or render in place.
lang: txt
signature: |-
  out.html: Undefined variable {{`missing`}} at line 3 in file content/intro.md
  out.html: Variable cycle in file content/intro.md: intro -> intro
  cvs/b.html (cvs/b.md): Undefined variable {{`title`}} in build[0] input
  out.html: Undefined variable {{`role`}} in folder candidatures/acme (var (config.yaml).applications)
  Undefined variable {{`slug`}} in build[0] output (page cvs/b.md)
---

#### Sites

| Site | Written |
| --- | --- |
| the output being written | `out.html:` first |
| the page it is made from | `cvs/b.html (cvs/b.md):` first |
| a content file | `in file content/intro.md` |
| a build entry | `in build[0] output` |
| a page, in its output path | `(page cvs/b.md)` |
| a `dirs` item | `in folder candidatures/acme` |
| a var | `var (config.yaml).applications` |

#### Behavior

- Every error carries its site. The innermost site is named, once.
- An error met while writing an output starts with that output, and with
  the page it is made from. An error in an output path has no output yet,
  and names the build entry and the page.
- An undefined reference in a multi-line template also carries its line.
  Lines count from the top of the file, frontmatter included.
- By default, the first error rejects [`run`](#run).
- A plain `Error` is a content error: [`dev`](#dev) and [`watch`](#watch)
  print its message alone, on one line. Any other kind, such as a
  `TypeError` in a transform, is a bug, and they print its stack.

#### inlineErrors

- With `inlineErrors: true`, a content error renders in place as an error box
  and is logged to the console. The rest builds.
- The box: class `minidoc-error`, a thin red border, a faint red background,
  the message HTML-escaped.
- The box replaces the smallest failing unit: a `dir` or `dirs` item, a page
  of `pages`, or the output.
- Output path errors stop the build in either mode.
- Meant for a dev server; leave it off in CI.

#### Example

```js
await run({ glob: "content/**/config.yaml", inlineErrors: process.env.DEV === "1" })
```

Guide: [When it breaks](./index.html#when-it-breaks).
