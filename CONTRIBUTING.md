# Contributing

This project follows the [épure](https://epuremethod.com) method.

## Working agreement

1. **Scenarios define behavior.** Write or change the scenario before changing
   behavior. Use the audience's vocabulary. A bug needs a scenario that
   reproduces it.
2. **Keep one current design.** Remove temporary designs when the scenarios
   replace them. Record lasting reasons in `DECISIONS.md`: date, decision,
   rejected alternative, and cost. Do not use it as a work log.
3. **Passing checks complete the work.** The scenarios and standing checks
   must pass. Step definitions are production-quality code. An incorrect step
   can hide incorrect behavior.

## Packages

One pnpm workspace. The root holds no code.

- `minidoc/` is the generator, package `@epure/minidoc`.
- `blocks/` is the common `:::` blocks, package `@epure/minidoc-blocks`:
  a line scanner, readers into nodes, the nodes' text form, renderers to
  HTML, `blocks.css` and two themes. Its scenarios are
  `blocks/test/*.test.yaml`, and the site draws them on its Blocks page.
- `docs/` is the documentation site, package `minidoc-docs`, private. It is
  built with minidoc and deployed to GitHub Pages on every push to `main`.

`pnpm build` at the root builds the package, then the site. `pnpm dev` serves
the site with minidoc's own dev server.

## Scenarios

The scenarios are YAML fixtures in `minidoc/test/*.test.yaml`, run by
`@epure/vitest`. A fixture is a `feature` with a `background` naming its
`given`, and `examples`, one `scenario` each. A scenario has a `source`
filesystem, optional run `options`, and either a `target`, the expected
outputs, or the `error` the run must reject with. The steps file,
`minidoc/test/steps.ts`, binds the `given`. It runs the public API against
the in-memory filesystem.

Two things cannot run on the in-memory filesystem, and they have plain
`node --test` files instead:

- `test/dev.test.mjs` drives `dev` and `watch` against a real filesystem and
  a real socket.
- `test/package.test.mjs` checks the packed package.

`pnpm check` at the root is the standing check. In `minidoc/` it runs the
fixtures, the dev tests and the package test; in `blocks/` the scenarios;
in `docs/` the site's build, which fails when a plate cannot be drawn.

## Architecture

```
minidoc/src/
  Schema.res         config and frontmatter schemas, path anchoring, the port
  Minidoc.res        contexts, rendering, the filesystems, run
  Minidoc.resi       the public interface
  Minidoc.res.d.mts  the same interface for TypeScript, written by hand
  Dev.res            watch and dev: the watcher, the rebuild loop, the server
```

All input and output goes through the injected `filesystem`. Transforms are
injected too. `Minidoc.res` never imports a Node module.

`Dev.res` is Node-only. It loads every builtin through a dynamic import, so
importing minidoc in a browser stays safe.

`Minidoc.resi` and `Minidoc.res.d.mts` change together.

## Session order

One session handles one bounded goal.

1. Write `SESSION.md`: what will change, why, and who it serves.
2. Write the fixture with its scenarios.
3. Add the implementation approach and rejected alternatives to `SESSION.md`.
4. Bind the scenarios in the steps file.
5. Build until the scenarios and standing checks pass.

Stop after each stage and wait for agreement. Do not present several stages
as finished together. Do not write steps or build before the fixture is
agreed.

When the session is green, append only lasting decisions to `DECISIONS.md`
and clear `SESSION.md`. The scenarios remain.

## Documentation

The reference lives twice: in `minidoc/README.md` and in the site's guide,
`docs/content/guide/`. A change to behavior changes both. The build writes
`llms.txt` and `llms-full.txt` from the guide.

Every change a user can see gets a line under "Unreleased" in the changelog
of `minidoc/README.md`. A change that breaks an existing config, a custom
filesystem or a caller starts with **Breaking:**.

## Writing

Write plain, natural English. Use common words, short sentences, active
voice, and concrete subjects. Put one claim in each sentence. Keep the
domain's exact vocabulary: config, build entry, var, context, template,
frontmatter, transform, output. Avoid metaphors, idioms and clever phrasing.

Use comments only for a domain rule, an external quirk, or an invariant that
the code and types cannot express. Keep them beside what they describe. Do
not comment fixtures. Put lasting rationale in `DECISIONS.md`. Delete stale
comments after changing code.

## Library references

Before using a library, read its version-matched
`node_modules/<package>/llms.txt` or `README.md`. If the reference does not
describe an API, ask before using it.
