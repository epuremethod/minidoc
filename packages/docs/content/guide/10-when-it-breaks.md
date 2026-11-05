---
title: When it breaks
slug: when-it-breaks
desc: Errors stop the build and say where they happened; inlineErrors shows
  content errors on the page instead, for a dev server.
refs: [errors, run]
---

Mara renames `lead` to `summary` in one chapter and forgets the template that
reads it.

```txt
dist/guide.html: Undefined variable {{`lead`}} at line 3 in file content/guide/02-parsing.md
```

### Loud, and sited

minidoc has no silent fallback. An undefined name, a reference cycle, a
missing file, an unknown var kind: each stops the build with a message that
says where. The site is the file, the build entry, the page or the folder
the error happened in — the innermost one, said once. In front of it comes
the output being written, and the page it is made from.

Line numbers count from the top of the file, frontmatter included. "line 3"
is line 3 in the editor.

```txt
dist/index.html: Variable cycle in file content/intro.md: intro -> intro
dist/how-to/b.html (how-to/b.md): Undefined variable {{`title`}} in build[0] input
dist/index.html: Undefined variable {{`role`}} in folder examples/03-holidays (var (config.yaml).examples)
```

An error in a transform's own code, such as a `TypeError`, is a bug rather
than a content error. `dev` and `watch` print its stack too.

### On the page

While writing, stopping the whole build for one typo is a nuisance. With
`inlineErrors`, a content error renders in place as a red box with the
message, and the rest of the page builds:

```js
await run({ glob: "content/**/config.yaml", inlineErrors: true })
```

The box replaces the smallest thing that failed: one item of a `dir` or
`dirs`, one page of `pages`. Each error is also logged. An output path that
cannot be resolved still stops the build — a file cannot be written without
a path.

Keep `inlineErrors` off in CI, where a broken page should fail the build.

::: story
Mara's draft chapter shows a red box where the broken reference is. The
other chapters, and every other page, are fine. She fixes the name and the
box goes away on the next build.
:::
