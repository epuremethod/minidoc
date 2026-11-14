---
slug: changelog
nav: Changelog
title: Changelog
fixture: changelog
---
A changelog says what each release adds, changes, fixes or removes. The
`::: changelog` block holds its entries, or names the markdown file that
holds them, by a path relative to the page, as an image does.
`::: release` draws the last release alone, for a home page. minidoc
reads the file and never writes it.

- An entry is an item of the top list: the date, `YYYY-MM-DD`, then the
  version in bold. The newest entry is first. `- Unreleased` holds the
  changes not released yet.
- A change is an item under its entry. It starts with its kind: `Add`,
  `Change`, `Fix` or `Remove`. A change with no kind is a `Change`. A
  change that breaks ends with `**Breaking**`.
- A package keeps its changelog in `CHANGELOG.md`, beside its
  `package.json`. A path that leads to no file stops the build.

A site gives the blocks a `read` option, `(path, page) => text`, which
resolves the path from `page.file`, the page's markdown file, and gives
`undefined` when there is no file. `@minidoc/core` gives each transform
its `page.file`.
