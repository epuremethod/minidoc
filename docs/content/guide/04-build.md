---
title: Build entries — inputs, pages, copies
slug: build
no: M-04
tag: Build entries
nav: Build
desc: Build entries — template or file/dir inputs, one output per file with
  pages, copy entries, output collisions, and how declared paths resolve
  against their config.
---

A build's `input` is a template string, or a `file`/`dir` mapping behaving
like the matching var kind. A file input's frontmatter merges in as the least
local layer — usable even in the output path:

```yaml
build:
  - output: "{{`slug`}}.html"    # slug from the file's frontmatter
    input:
      file: content/home.md
  - output: guide.html
    input:
      dir: content/guide
      each: "<section>{{`body`}}</section>"
```

An input with a `copy` key copies a file or directory (recursively) without
reading or rendering its content. The paths may contain ``{{`refs`}}``; the
copied bytes never do:

```yaml
build:
  - output: public/style.css
    input: { copy: assets/style.css }
  - output: public/fonts
    input: { copy: assets/fonts }
```

### Pages — one output per file

`pages` fans a build entry out over a folder: one output per matched file.

```yaml
var:
  layout:
    file: layout.html
build:
  - pages: { dir: cvs, glob: "*.md" }
    output: "../dist/{{`file.stem`}}.html"
    var:
      content: "{{`page`}}"        # the page's rendered body
    input: "{{`layout`}}"
```

Each page renders the entry's `input` in its own child context: the file's
frontmatter layers in like a `file` var's — over the config's vars, under the
entry's own `var` — plus ``{{`page`}}``, its rendered body, and
``{{`file.name`}}`` / ``{{`file.stem`}}`` / ``{{`file.dir`}}`` (its parent
folder's name). All of it is usable in the output path, so a `slug:` in every
frontmatter is optional. A page's frontmatter stays local to that page.
`dir`, `glob` (default `*.md`), `transform` and `order` work as for a `dir`
var; the `input` may be a template or a `file`, not a `copy`. An empty match
fails loud; `optional: true` accepts it and writes nothing.

A glob with a `/` reaches into subfolders — one page per folder:

```yaml
var:
  layouts.cv:                  # a dotted name, not a nested mapping
    file: layouts/cv.html
build:
  - pages: { dir: candidatures, glob: "*/cv.md" }
    output: "../dist/{{`file.dir`}}-cv.html"   # dist/2026-01-acme-cv.html
    input: "{{`layouts.cv`}}"
```

Every output path resolves before anything is written. Two outputs resolving
to the same path — two pages sharing a slug, two entries — fail loud, naming
both; copies into one directory merge and are exempt:

```
Output path collision: dist/same.html is written by both build[0] (page cvs/a.md) and build[0] (page cvs/b.md)
```

### Paths

Declared paths (`base`, `output`, `file`, `dir`, `dirs`, `pages`, `copy`) are
relative to the layer that declares them: a config's paths to that config's
folder, a frontmatter's paths to its content file's folder, a `dirs` item's
vars to that item's subfolder. Paths are templates like any other and may
depend on anything — a var, a page's frontmatter, another file's frontmatter
— but refs only contribute segments after the anchor: they never move it.
Absolute paths (`/...`) written as such pass through untouched. Wherever a
path leads, the Node filesystem only reaches inside its root and the folders
it [allows](#api).
