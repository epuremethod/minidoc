---
title: Words in files
slug: words-in-files
desc: The file var — markdown rendered to HTML, frontmatter read under the
  var's name, optional files and wrappers.
refs: [file, frontmatter, transform]
---

HTML inside YAML is fine for a heading. For a page of prose, Mara wants a
markdown file.

### A file var

A var with a `file` key loads its template from that file:

```yaml
var:
  intro:
    file: intro.md
```

The extension picks the transform: `.md` is rendered from markdown to HTML,
`.html` is kept as it is. References in the file render first, then the
transform runs. A markdown file can therefore pull in other templates, and
they are rendered as part of its markdown.

```md
<!-- content/intro.md -->
---
title: Dates, small
lead: One function per question you ask about a date.
---

**{{`site`}}** answers questions about dates and nothing else.
```

### Frontmatter belongs to the var

The block between the `---` lines is the file's frontmatter. Its names form
the innermost layer of the file's own context: inside `intro.md`,
``{{`title`}}`` is *Dates, small*.

The config reads those names under the var's name. ``{{`intro.title`}}`` and
``{{`intro.lead`}}`` work anywhere in the config — in a template, in another
file, even in an output path:

```yaml
build:
  - output: ../dist/index.html
    input: "{{`layout`}}"
    var:
      title: "{{`intro.title`}} — {{`site`}}"
      main: "<p class='lead'>{{`intro.lead`}}</p>{{`intro`}}"
```

Two file vars can both have a `title` without conflict: one is
``{{`intro.title`}}``, the other ``{{`install.title`}}``.

### Optional files

A missing file is an error. Mara wants a banner that exists only when she
writes one:

```yaml
var:
  banner:
    file: banner.md
    optional: true
    template: "<aside class='banner'>{{`body`}}</aside>"
```

With `optional: true`, a missing file renders as nothing. `template` wraps
the rendered file as ``{{`body`}}`` — and renders nothing at all when the
body is empty, so the page never shows an empty `aside`.

::: story
The release week, Mara writes `banner.md`: *marmot 2.0 is out*. The week
after, she deletes it. Neither change touches the config.
:::
