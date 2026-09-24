# minidoc

A small documentation website generator, part of the
[épure](https://epuremethod.com) toolset.

This is a pnpm workspace:

- [`minidoc/`](minidoc/README.md) — the `@epure/minidoc` package: model, API, reference.
- [`docs/`](docs) — the documentation site, built with minidoc (tilia all the
  way down), deployed to GitHub Pages on every push to `main`.

```sh
pnpm install
pnpm build     # build the package, then the site into docs/dist
pnpm dev       # minidoc's own dev server on the docs — watch, rebuild, live reload
pnpm check     # everything the CI runs
```
