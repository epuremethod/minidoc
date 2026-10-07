---
name: errors
slug: errors
kind: rule
summary: Errors stop the build and name where they happened — or render in place.
lang: txt
signature: |-
  Undefined variable {{`missing`}} at line 3 in file content/intro.md
  Variable cycle in file content/intro.md: intro -> intro
  Undefined variable {{`missing`}} in build[0] output
  Undefined variable {{`slug`}} in build[0] output (page cvs/b.md)
  Undefined variable {{`role`}} in folder candidatures/acme (var (config.yaml).applications)
---

#### Sites

| Site | Written |
| --- | --- |
| a content file | `in file content/intro.md` |
| a build entry | `in build[0] output` |
| a page | `(page cvs/b.md)` |
| a `dirs` item | `in folder candidatures/acme` |
| a var | `var (config.yaml).applications` |

#### Behavior

- Every error carries its site. The innermost site is named, once.
- An undefined reference in a multi-line template also carries its line.
  Lines count from the top of the file, frontmatter included.
- By default, the first error rejects [`run`](#run).

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
