---
title: Var kinds — file, dir, dirs, list, value
slug: vars
no: M-03
tag: Var kinds
nav: Vars
desc: The five var kinds — file, dir, dirs, list, value — plus transform
  inference from file extensions, frontmatter, optional files and ordering.
---

Every var is a template plus, optionally, a source and a transform. A plain
string is just a template; a group holding one of the keys below renders as
that kind. The key is read after layers merge (see [nested vars](#model)), so
each field of a kind can be overridden on its own.

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

A content file may start with a YAML frontmatter block — scalars, lists
and nested groups. The body renders in a child context of that frontmatter,
and the declaring context reads it under the var's name: `{{`intro.title`}}`
is the `title` of the file `intro` loads — usable even in an output path. Two
files can share frontmatter names without conflict, each under its own var.

A missing file fails loud. `optional: true` renders it as an empty string
instead (and it exports no frontmatter). An optional `template` wraps the
rendered body as ``{{`body`}}``, in the file's frontmatter context; like a
`list` wrapper, it renders nothing when the body is empty — a missing
optional file, or one with only frontmatter or whitespace:

```yaml
var:
  email:
    file: email.md
    optional: true
    template: '<section><h3>{{`subject`}}</h3>{{`body`}}</section>'
```

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
its rendered content as ``{{`body`}}``. Items join with newlines, in filename
order (prefix files `01-intro.md` to control it); `order: desc` reverses it,
so date-prefixed files list newest first. `glob` (default `*.md`) selects
files; a glob with a `/` reaches into subfolders (`*/cv.md` one level down,
`**/cv.md` any depth), ordered by path. `transform` overrides the per-file
inference; `join` (default a newline) sits between items. Unlike `file`
vars, items do *not* export their frontmatter outward — eight chapters would
conflict on `title`; it stays local to each item. Each item also sees its
file name: ``{{`file.name`}}`` (`01-intro.md`), ``{{`file.stem`}}``
(`01-intro`) and ``{{`file.dir`}}``, the name of its parent folder. An empty
match fails loud; `optional: true` accepts it (or a missing folder) and
renders nothing.

### dirs

Iterates over the subfolders of a folder: one item per subfolder, rendered
through `each`. The item's own `var` block loads in each subfolder — its
`file` and `dir` paths are relative to that subfolder — so one row can use
several files of the folder:

```yaml
var:
  applications:
    dirs: candidatures           # candidatures/2026-01-acme/cv.md, ...
    order: desc                  # newest folder first
    each: '<tr><td>{{`folder.name`}}</td><td>{{`cv.role`}}</td><td>{{`email`}}</td></tr>'
    var:
      cv: { file: cv.md }
      lettre: { file: lettre.md }
      email: { file: email.md, optional: true }
```

Each item sees ``{{`folder.name`}}``, also usable in its paths
(`file: "{{`folder.name`}}.md"`). The frontmatter of its files reads under
their names — `{{`cv.role`}}`, `{{`lettre.company`}}` — and stays local to the
item.
Folders list in name order; `order: desc` reverses it. `each` is required. A
missing file in any folder fails loud (unless that var is `optional`); an
empty or missing folder fails loud unless `optional: true`, which renders
nothing.

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
