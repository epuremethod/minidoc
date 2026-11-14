---
slug: a-page
nav: A page
title: A page is markdown with frontmatter
---
A page is a markdown file. Its frontmatter holds what the layout needs:
the title, the place in the menu, the language. Its body is what the
editor edits. The editor already keeps the frontmatter as it is.

A page can name more files, as its sections, with a glob in its
frontmatter. Each file is a section that is edited on its own, in the
order of the glob. The Guide is one head and thirteen chapters:

```markdown
---
title: Guide
sections: guide/*.md
---
minidoc, told as one story.
```

A single page has no `sections`:

```markdown
---
title: Callouts
nav: Callouts
lang: en
---
A callout sets a few lines apart and says what they are.
```

::: proposed
**The layout is a React component, drawn and hydrated with the sections**
At build, core draws the whole page, the layout and the sections, with
`react-dom/server`: one tree, one render. In live, the script hydrates
that tree. The frontmatter of every page lands through the sync, as the
sections do. A renamed page then changes the menu of each open page, and
nothing outside the editor is replaced.

Rejected: a function that returns a string. In live, a change to the
frontmatter must draw the string again and replace the elements around
the mounted editors. The caret and the open panel are lost: the blink
again, one level up.

Cost: a site writes JSX, and `dev` bundles the layout for the browser
with esbuild, as it bundles the editor today. An output that is not
HTML, such as `llms.txt`, keeps a plain function that returns text.
:::

### Sections and their titles

Today the title of a section is in its file's frontmatter, with its
`slug` and its `nav`. A template of `config.yaml` puts the title in an
`h2` above the body, and a second template lists the titles in the
contents. The editor does not see the title: to change it, a person edits
the frontmatter in another program, and the page rebuilds.

::: proposed
**A section's title is the first heading of its file**
A section file starts with its title, as a heading of the body:

```markdown
---
nav: Two renders
---
# Two renders of one page

Today a page of a minidoc site has two renders.
```

- The editor draws the heading where it stands, and the person edits it
  in place, as any other text.
- core reads `title` from the section: the text of its first heading.
  It is a value of tilia, so each reader of it draws again when it
  changes. See [The state](#state).
- The contents and the running head read `title`. They follow a key in
  the heading after the editor's pause. A change of the heading on disk
  lands through the sync and changes them too.
- `slug` comes from the file's name: `01-two-renders.md` is
  `two-renders`. A link to the section stays when its title changes.
- `nav` stays in the frontmatter, for a short label. Without it, the
  contents show the title.

Rejected: the title in the frontmatter. The editor keeps the frontmatter
as it is and draws nothing of it, so the title is the one text of the
page that the page cannot edit.

Cost: each section file moves its `title` from the frontmatter to a
heading. The site styles the editor's heading, not a heading of its
template: today's `.chapter__title` becomes a rule on the first heading
of a section.
:::

The layout receives `site` and `page`. `page.sections` gives each section
its `slug`, its `title`, its `nav`, and `body`: the editor's view of the
file. A page with no `sections` has one, its own file. The menu, the
current page and a layout for each kind of page are in
[The site](#site).
