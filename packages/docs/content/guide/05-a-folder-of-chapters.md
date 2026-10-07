---
title: A folder of chapters
slug: a-folder-of-chapters
desc: The dir var renders a folder of files through one template — the same
  folder read twice for a table of contents and the chapters.
refs: [dir, frontmatter]
---

The guide will have chapters, and Mara wants each in its own file. Adding a
chapter should mean adding a file, nothing else.

### A dir var

A var with a `dir` key renders every file of a folder through its `each`
template:

```yaml
var:
  chapters:
    dir: guide
    each: |-
      <section id="{{`slug`}}">
        <h2>{{`title`}}</h2>
        {{`body`}}
      </section>
```

Each file renders in its own context: its frontmatter, plus ``{{`body`}}``,
its rendered content. ``{{`title`}}`` in `each` is the title of the file
being rendered. The items are joined with newlines.

```md
<!-- content/guide/01-install.md -->
---
title: Install
slug: install
---

`pnpm add marmot`, and import what you need.
```

### Two views of one folder

The table of contents is the same folder, read again through another
template:

```yaml
var:
  toc:
    dir: guide
    each: '<li><a href="#{{`slug`}}">{{`title`}}</a></li>'
```

`toc` and `chapters` can never disagree: both come from the same files.

### Order

Files are rendered in name order, so Mara prefixes them: `01-install.md`,
`02-parsing.md`. `order: desc` reverses it — for a changelog in dated files,
newest first.

Each item also knows its file: ``{{`file.name`}}`` is `01-install.md`,
``{{`file.stem`}}`` is `01-install`, and ``{{`file.dir`}}`` is the folder it
sits in. A `slug` in every frontmatter is a choice, not a requirement.

### Frontmatter stays inside

A file var shares its frontmatter with the config under the var's name. A dir
var does not: eight chapters would all define `title`. Each item's
frontmatter stays in that item.

::: story
Mara writes `03-formatting.md`, saves, and the chapter appears in the
contents and on the page, in third place.
:::
