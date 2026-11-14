---
slug: what-goes
nav: What goes
title: What goes, and what it costs
---
The wrapper keeps the filesystem, `dev`, `watch`, the port, and the
blocks. It drops this:

- **The var kinds**: `file`, `dir`, `dirs`, `list` and `value`, with
  `each`, `join` and `template`. A layout does their work in React.
- **Braces in a page.** Braces in markdown are text again.
- **Transforms by name**: `md`, `none`, and a site's own. A pipeline
  replaces a transform that reads a file, and a site block replaces one
  that draws.
- **The build entries of `config.yaml`.** A copy is a line of the build
  script.
- **The rebuild and the reload in `dev`.** A change lands through the
  sync. `dev` builds once, at the start.

This breaks every site that uses minidoc today:

- **radif** puts eleven vars in braces in its pages, in twenty places:
  `scenarios`, `rootDiagram`, `gateDoc`, and others. Each becomes a site
  block, and each transform becomes a pipeline or a draw.
- **gdos, maia and the vs projects** keep their page shell in
  `config.yaml`. Each moves it to a layout component.
- **These docs** lose most of the API page: config, var kinds, build
  entries and rules. Chapters 3 to 9 of the guide tell the story of the
  vars, and need a new story. `llms.txt` is built from vars too, and
  becomes a second layout.

::: settled
**No compatibility layer**
The release is not out yet. A layer that keeps `config.yaml` would keep
the two renders, and the two renders are the problem.
:::
