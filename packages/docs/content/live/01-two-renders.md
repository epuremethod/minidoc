---
slug: two-renders
nav: Two renders
title: Two renders of one page
---
Today a page of a minidoc site has two renders. The build writes static
HTML: markdown-it reads the markdown, and the blocks package draws each
`:::` block. In `dev`, the page then loads the editor. The editor fetches
the same markdown, reads it again as its own blocks, and draws its own
elements in place of the static HTML.

::: sequence The page in dev
build page editor
build -> page  static HTML
page = static
page -> editor  mount
editor -> build  fetch the markdown
build -> editor  the file
editor -> page  new elements
page = live
:::

Two renders give two results:

- **The styles change.** `site.css` styles the elements of markdown-it.
  The editor's elements have other classes, and its own stylesheet
  styles them.
  The page blinks when the editor replaces the static HTML.
- **Images are lost.** The editor reads `![alt](src)` as text, and shows
  the markdown. The editor knows an image atom, but the page reader does
  not make one.
- **A change on disk reloads the page.** A save by another program, git
  or an agent rebuilds the site, and the page reloads. The caret, the
  open panel and the scroll are lost. A computed part, such as a
  diagram, changes only with a rebuild.
- **Each fix goes in two places.** A change to how a text looks goes in
  both renders. The docs' Chrome check compares them word by word to find
  the gaps.

Neither render is wrong. The problem is that there are two.
