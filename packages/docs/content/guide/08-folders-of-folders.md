---
title: Folders of folders
slug: folders-of-folders
desc: The dirs var iterates over subfolders, loading several files from each;
  globs with a slash reach into subfolders.
refs: [dirs, dir, pages]
---

Mara's examples are not single files. Each is a folder: a `readme.md`
explaining it, and an `example.ts` that runs.

```txt
content/examples/
  01-today/
    readme.md
    example.ts
  02-business-days/
    readme.md
    example.ts
```

### A dirs var

A `dirs` var renders one item per subfolder. Its own `var` block is loaded in
each subfolder, so one item can use several files:

```yaml
var:
  examples:
    dirs: examples
    each: |-
      <section id="{{`folder.name`}}">
        <h2>{{`readme.title`}}</h2>
        {{`readme`}}
        {{`code`}}
      </section>
    var:
      readme: { file: readme.md }
      code:
        file: example.ts
        transform: typescript
```

Inside `each`, ``{{`folder.name`}}`` is the subfolder's name, and each file's
frontmatter reads under its var's name: ``{{`readme.title`}}``. The paths of
the item's `var` are relative to the subfolder. `example.ts` has no extension
minidoc knows, so its `transform` is given.

A missing file stops the build, naming the folder — unless that var is
`optional`. Folders come in name order; `order: desc` reverses it.

### Globs that reach down

When one file per folder is enough, a `dir` var or `pages` can reach into
the subfolders with a glob holding a `/`:

```yaml
build:
  - pages: { dir: examples, glob: "*/readme.md" }
    output: "../dist/examples/{{`file.dir`}}.html"
    input: "{{`layout`}}"
    var:
      main: "{{`page`}}"
```

`*/readme.md` matches one level down, `**/readme.md` at any depth. Here
``{{`file.dir`}}`` is the name of each readme's folder, so
`01-today/readme.md` becomes `examples/01-today.html`.

::: story
A contributor sends a pull request adding `03-holidays/`, with a readme and
an example. Mara merges it. The site has a third example and the config has
not changed.
:::
