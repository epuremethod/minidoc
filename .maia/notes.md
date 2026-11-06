::: plan minidoc release 0.2.0
1. [x] **docs:dev** committed
   - [x] Root script `docs:dev` starts the documentation
   - [x] Commit rule in AGENTS.md
2. [/] **Finish the work in progress** waiting on .maia/
   - [x] Finish the `plan` block (Plan.res, themes, docs page 12-plans)
   - [x] Add `packages/deprecated/` and its CONTRIBUTING line
   - [x] `pnpm check` passes at the root, and on each commit
   - [x] Commit one feature per commit
   - [ ] Clean tree: `.maia/` is untracked, and `pnpm pub` refuses a dirty tree
3. [/] **Prepare the versions** waiting on you
   - [x] Versions: core 0.2.0, blocks 0.1.0, @epure/minidoc 0.2.0
   - [ ] Changelog: "Unreleased" becomes "0.2.0" in packages/core/README.md
   - [ ] Decide a tag scheme for blocks (core tags `v0.2.0`)
   - [ ] Give blocks and deprecated a publish path
4. [ ] **Get npm access** needs you
   - [ ] `npm login` on this machine
   - [ ] The `@minidoc` scope exists and you can publish to it
5. [ ] **Publish**
   - [ ] `@minidoc/core` 0.2.0 with `pnpm pub` (tags v0.2.0)
   - [ ] `@minidoc/blocks` 0.1.0
   - [ ] `@epure/minidoc` 0.2.0, after core: it depends on `@minidoc/core` ^0.2.0
   - [ ] `npm deprecate @epure/minidoc "Renamed to @minidoc/core"`
6. [ ] **Ship**
   - [ ] Push main and the tags; the docs deploy to GitHub Pages
   - [ ] Install the packages in a scratch project and build a page
   - [ ] Move radif, vs/* and muse to `@minidoc/core` and `@minidoc/blocks`
:::

## hello
_what_ is **this** ?