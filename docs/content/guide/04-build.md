---
title: Build entries — inputs, outputs, copies
slug: build
no: M-04
tag: Build entries
nav: Build
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

### Paths — the one exception

Declared paths (`base`, `output`, `file`, `dir`, `copy`) are relative to the
config file that declares them, anchored at parse time. Paths may contain
``{{`refs`}}``, but they resolve against plain string vars only — paths must
resolve before content loads, so they can never depend on it. Refs can
contribute path segments but never move the anchor; absolute paths (`/...`)
pass through untouched.
