# minidoc

A small documentation website generator, part of the
[épure](https://epuremethod.com) toolset.

Documentation: [minidoc.dev](https://minidoc.dev). For LLMs and agents:
[llms.txt](https://minidoc.dev/llms.txt) (index) and
[llms-full.txt](https://minidoc.dev/llms-full.txt) (the full guide, one
markdown file).

This is a pnpm workspace:

- [`packages/core/`](packages/core/README.md) — the `@minidoc/core` package: model, API,
  reference, `dev`, and the changelog.
- [`packages/blocks/`](packages/blocks) — the `@minidoc/blocks` package: the `:::` blocks as
  HTML, `blocks.css` and the themes.
- [`packages/live/`](packages/live) — the `@minidoc/live` package: the same blocks in React,
  and `@minidoc/live/edit`, the dev page's editor.
- [`packages/docs/`](packages/docs) — the documentation site, built with minidoc (tilia all the
  way down), deployed to GitHub Pages on every push to `main`.

```sh
pnpm install
pnpm build     # build the packages, then the site into packages/docs/dist
pnpm docs:dev  # minidoc's own dev server on the docs — watch, rebuild, live reload
pnpm check     # everything the CI runs
```
