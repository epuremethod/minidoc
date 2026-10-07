---
title: A page per file
slug: a-page-per-file
desc: Fan a build entry out over a folder with pages — one output per file,
  named from its frontmatter or its file name.
refs: [pages, build, output]
---

The guide reads well as one long page. The how-to articles do not: each
answers one question, and people link to them one by one. Mara wants one
HTML file per article.

### pages

A build entry with `pages` writes one output for each file of a folder:

```yaml
build:
  - pages: { dir: how-to }
    output: "../dist/how-to/{{`file.stem`}}.html"
    input: "{{`layout`}}"
    var:
      main: "<h1>{{`title`}}</h1>{{`page`}}"
```

Each page renders the entry's `input` in its own context. The file's
frontmatter is a layer there, and two names are added: ``{{`page`}}``, the
file's rendered body, and ``{{`file.name`}}``, ``{{`file.stem`}}`` and
``{{`file.dir`}}``. Every one of them works in the output path.

`how-to/parse-iso-dates.md` becomes `dist/how-to/parse-iso-dates.html`,
with its own title in the tab.

### Collisions

Every output path is resolved before anything is written. When two outputs
land on the same path — two articles with one slug, two entries writing one
file — the build stops and names both:

```txt
Output path collision: dist/how-to/dates.html is written by both build[1] (page how-to/dates.md) and build[1] (page how-to/old/dates.md)
```

Copies into one folder are the exception: they merge.

### Output in place

A run writes over its outputs and never empties the output folder first. A
server keeps serving the old files until the new ones land. A file Mara
deletes from `how-to` leaves its old page in `dist` until she cleans it; this
site's build removes `dist` before each run for that reason.

::: story
Sam links a user to `how-to/convert-zones.html`. The page has its own
title, its own description, and the same layout as the rest of the site.
:::
