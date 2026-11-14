---
title: A README outgrown
slug: a-readme-outgrown
desc: Who minidoc is for, what it does and what it leaves to you — and the
  story this guide follows.
refs: []
---

This chapter is for the person deciding whether minidoc fits their project.
There is no code in it.

minidoc is a small documentation website generator. It reads YAML configs,
fills templates with your content, and writes files. It has no theme, no
plugin system and no expression language. The HTML, the CSS and the fonts are
yours; minidoc puts the words in the right place.

::: story
Mara maintains `marmot`, a small date library. Its README has grown to
eleven screens. People land in the middle of it, scroll the wrong way, and
open issues whose answer is three headings up. Mara wants a site: a guide
that tells the library's story, a reference that lists every function, and
nothing she has to maintain twice.
:::

### One idea

Everything in minidoc follows from one rule:

> A **context** is a tree of templates. A child context is its parent's tree
> merged with its own — own wins. Everything renders in its nearest context.

A config declares templates. A page adds its own. A markdown file's
frontmatter adds its own again. When a template is rendered, each
reference in it is looked up in the nearest context that defines it. That is
the whole engine. The chapters that follow are this rule, applied to
folders, files and pages.

### What minidoc leaves to you

- **The look.** You design one HTML layout, or have one designed, or
  vibe-code one. minidoc never adds markup you did not write.
- **The shape.** You decide which pages exist and how the sources are cut:
  one file per chapter, one file per function, one folder per example.
- **The words.** You write them, or an agent does once the shape is fixed.

### How a site gets made

The order that works:

1. **Design** the layout first, with placeholder text.
2. **Install** minidoc and write a config that produces that one page.
3. **Fix the shape** of the sources: the folders, the frontmatter each file
   carries, one example file of each kind.
4. **Fill the files**, by hand or with an agent that follows the shape.
5. **Run the dev server** and watch the site grow as files land.

The site you are reading was made this way. Its sources are
[in the repository](https://github.com/epuremethod/minidoc/tree/main/packages/docs).

### How this guide works

The guide follows Mara from an empty folder to a finished site. Each chapter
adds one idea and the config lines that use it. When you need the exact
fields of something, the [API reference](./api.html) has one entry for each,
and every chapter ends with links to the entries it used.
