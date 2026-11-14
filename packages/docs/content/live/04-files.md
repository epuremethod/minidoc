---
slug: files
nav: Files and sections
title: Each file has a pipeline to the editor
---
The editor is made for a web app where several people edit the same
document together. Each person's page holds sections. A change goes to
the server, and the server sends it to the other pages. Each page merges
what lands with what its person typed, by the editor's three-way merge.

minidoc takes the same architecture, on one machine. There is no remote
server. The other co-authors are the files: a save from another editor,
a `git pull`, an agent that writes a page. A small local socket between
`dev` and each open page takes the place of the remote sync.

minidoc's work is to say which file goes through which pipeline:

| Filesystem | Rendered as |
| --- | --- |
| `some.md` | a section: its prose, callouts and drawings |
| `foo.yaml` | a section made of atoms and blocks, such as a fixture's scenarios |
| `image.png` | a row with the bytes, that an image atom names |

A pipeline is two-way. `read` maps a file to its section, and `write`
maps the section back to the file. A file that a page only shows, and
never edits, has no `write`.

```rescript
// Site.res, its files: each glob and its pipeline
files: dict{
  "content/**/*.md": Minidoc.markdown,
  "content/**/*.{png,jpg,svg}": Minidoc.image,
  "../blocks/test/*.test.yaml": Fixture.pipeline,
},
```

```rescript
// Fixture.res: a pipeline of the site's own
let pipeline: Minidoc.pipeline = {
  read: text => Plates.section(text),
  write: Some(section => Plates.yaml(section)),
}
```

```js
// Site.mjs, its files
files: {
  "content/**/*.md": Minidoc.markdown,
  "content/**/*.{png,jpg,svg}": Minidoc.image,
  "../blocks/test/*.test.yaml": Fixture.pipeline,
},
```

`read` takes the file's text and gives the editor's section. `write`
gives the text back. minidoc keeps the ids of the blocks across reads,
with the editor's `Identity.read`, so a pipeline never mints them.

`Minidoc.markdown` is the page reader of today: a block that nobody
changed writes back with the same bytes. A site writes its own pipeline
for a file that only it knows.

At the start, minidoc reads every file through its pipeline. That gives
the two-way mapping, Filesystem ⟷ Editor. The build draws the editor's
view of the sections, and `dev` keeps the mapping in sync.
