::: plan minidoc release, with live minidoc
1. [x] **Ready to publish** committed
   - [x] Root `pnpm docs:dev`, commit rules in AGENTS.md
   - [x] Plan block, `@epure/minidoc` re-export, blocks pages in llms.txt
   - [x] Root `pnpm pub <core|blocks|deprecated>`: core tags `v…`, blocks `blocks-v…`
2. [x] **Every block live** maia 4bc6847
   - [x] Cut from the notes as minidoc cuts them
   - [x] Drawn by minidoc itself, in the reading theme
   - [x] A click opens the source, with a live preview
   - [x] Edits survive Claude writing the file
3. [ ] **React renderers** about 3–5 d
   - [ ] Nodes to JSX: one source for the site and the editor
   - [ ] A package of its own, say `@minidoc/live`, so the site needs no React
4. [ ] **The plan, moved into minidoc** about 1–2 d
   - [ ] With minidoc's long layout; maia's own copy goes
5. [ ] **Flows, screens, API calls** edited in place
   - [ ] Flow steps, like the plan's todos
   - [ ] Screen fields and buttons as inputs
   - [ ] API method, path, fields and bodies as inputs
6. [ ] **Callouts' prose** edited in place
   - [ ] Kind, title and byline as fields
   - [ ] Prose: an editor nested in the block (2–3 d), or blocks that hold blocks in the editor core (1–2 w)
7. [ ] **Diagrams** click to line
   - [ ] Sequence, states, model: source with live re-layout, a click jumps to the line
8. [ ] **Prepare the versions**
   - [ ] Versions for core, blocks, the live package and `@epure/minidoc`
   - [ ] Changelog: "Unreleased" gets the release date
   - [ ] `pnpm pub` knows the live package and its tag
9. [ ] **Get npm access** needs you
   - [ ] `npm login` on this machine
   - [ ] The `@minidoc` scope exists and you can publish to it
10. [ ] **Publish**
   - [ ] `pnpm pub core`, then blocks, then the live package
   - [ ] `pnpm pub deprecated`, after core; it runs `npm deprecate`
11. [ ] **Ship**
   - [ ] Push main and the tags; the docs deploy to GitHub Pages
   - [ ] Install the packages in a scratch project and build a page
   - [ ] Move radif, vs/* and muse to `@minidoc/core` and `@minidoc/blocks`
:::

## hello
_what_ is **this** ?