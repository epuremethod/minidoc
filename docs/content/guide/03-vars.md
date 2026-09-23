---
title: Var kinds — file, dir, list, value
slug: vars
no: M-03
tag: Var kinds
nav: Vars
---

Every var is a template plus, optionally, a source and a transform. A plain
string is just a template. A mapping picks a kind by its key.

### file

Loads its template from an html/md file:

```yaml
var:
  intro:
    file: content/intro.md       # markdown -> html, inferred from extension
  snippet:
    file: content/raw.md
    transform: none              # explicit override of the inference
```

The transform is inferred from the extension (`.md`/`.markdown` -> `md`,
`.html`/`.htm` -> `none`); an unknown extension without an explicit
`transform` fails loud. ``{{`refs`}}`` in the body render first, then the
transform runs — so a var can inject markdown that gets rendered.

A content file may start with a YAML frontmatter block of scalars and scalar
lists. The body renders in a child context of that frontmatter, and — for
single `file` vars — the frontmatter also merges into the declaring context,
just below its explicit vars (so an explicit `var: title:` wins). Two files
in one block exporting the same name is a conflict and fails loud. Dots are
ordinary characters in names, so dotted namespaces like `signature.ts` are
fine.

### dir

Loads a folder of content files and renders each through an `each` template —
the building block for a guide or an API reference:

```yaml
var:
  toc:
    dir: guide
    each: '<li><a href="#{{`slug`}}">{{`title`}}</a></li>'
  chapters:
    dir: guide                   # the same folder, a second view
    each: '<section id="{{`slug`}}">{{`body`}}</section>'
```

Each item's `each` renders in a child context of the file's frontmatter plus
its rendered content as ``{{`body`}}``; items join with newlines, in filename
order (prefix files `01-intro.md` to control it). `glob` (default `*.md`)
selects files; `transform` overrides the per-file inference. Unlike `file`
vars, items do *not* export their frontmatter outward — eight chapters would
conflict on `title`; it stays local to each item. An empty match fails loud.

The chapters you are reading — and the nav above them — are two `dir` views
of one `guide` folder, exactly like this example.

### list

Renders a scalar list (from config or frontmatter) through an item template.
`each` sees the scalar as ``{{`item`}}``; an optional `template` wraps the
`join`ed items as ``{{`body`}}``. An empty list renders nothing, wrapper
included:

```yaml
var:
  refsBlock:
    list: refs
    each: '<a href="./api.html#{{`item`}}">{{`item`}}</a>'
    join: ", "
    template: '<p>Reference: {{`body`}}</p>'
```

### value

Renders an inline template through a named transform. Because you inherit
formulas, a `value` var declared once re-renders wherever it is used — inside
a dir's `each` it sees that item's frontmatter:

```yaml
var:
  signatureHtml:
    value: "{{`signature.ts`}}"
    transform: typescript
  entries:
    dir: api
    each: "{{`signatureHtml`}}{{`body`}}"   # per-item signature, one declaration
```
