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
3. [x] **React renderers** done
   - [x] The editor's rule is `{data, view}` (editor 525263e, bf86c32)
   - [x] a. Intention agreed: `@minidoc/live`, every block drawn once in our own JSX with fields, no editor dependency, maia switches
   - [x] b. Testing agreed: HTML contract + sequence, states, model; fields.test.yaml; live draws the contract as DOM; live and pane fixtures
   - [x] c. Technical agreed: a plain tree by our own JSX, HTML or React; one rule for every block; maia keeps the click in place
   - [x] d. Built: `pnpm check` passes (core 131, blocks 106, live 25); maia 284 tests
   - [x] Decisions in DECISIONS.md, SESSION.md cleared, handoff written
   - [x] Committed: minidoc 9316c1c, maia 543b2b0 (each checked on its own)
   - [x] e. You look in maia
4. [x] **The plan, moved into minidoc** minidoc 47356eb, maia 021d77a
   - [x] a. Intention agreed: edited in place by live; a text shows markdown only under the caret; an edit changes only what it touches
   - [x] b, c. Tests and technical agreed: edits in blocks, the drawing names its clicks, the plan an ordinary block in maia
   - [x] d. Built: edits, untick, Enter split, done stage moves back, the editor's line as the text field, the real-Chrome hit and look check
   - [x] The editor fixed the line's caret and crash (editor 7a681d8)
   - [x] The calmer stage list: number and title on one line, mark at the right, message below, no counts, one third wide
   - [x] e. You tried it in maia; 11 decisions; checks green (blocks 129, live 51; 450 clicks, 74 texts)
   - [x] Committed: minidoc 47356eb; maia 021d77a, and its crash guard a235a0e
5. [x] **Drawings through their source** minidoc ec8123e
   - [x] The plan rethought: the page is the editor; text in place, drawings through their source
   - [x] a, b, c agreed: `Live.Pane` is the source only; `Live.Drawing` keeps the last good form; maia gives each drawing's rule a pane
   - [x] d. Built in minidoc (live 52) and in maia by its session (338 tests)
   - [x] e. You tried it in the docs
6. [x] **minidoc's dev page is the editor** minidoc 163edfd, be14e05
   - [x] a. `pnpm docs:dev` serves the docs as an editor; markdown read into blocks and atoms as CommonMark groups it; one editor view per section
   - [x] b, c. Tests and technical agreed: `@minidoc/edit`, dev's edit option, save route and reload rule, the round trip over every docs file, ReScript 12.3.1
   - [x] d. Built: guide, Blocks and API editable; core 131 + 28 dev, blocks 129, live 52, edit 8, docs 3
   - [x] e. You edited the docs: it works; 9 decisions
   - [x] Committed in three commits, each checked on its own
7. [ ] **Callouts in place** intention → tests → technical → build → next
   - [ ] A callout's title and text edited where they stand, as text, tested in the docs
   - [ ] The editor's session: `Block ~tag`, code spans with a backtick, the prefix fix (waiting for you there)
   - [ ] Then minidoc drops its block-id workaround and renames `Line` where it names it
8. [ ] **Prepare the versions**
   - [ ] The names: one family, épure (your answer)
   - [ ] Versions for core, blocks, the live package and `@epure/minidoc`
   - [ ] maia's docs move to the published blocks
   - [ ] Changelog: "Unreleased" gets the release date
   - [ ] `pnpm pub` knows the live package and its tag
9. [ ] **Get npm access** needs you
   - [ ] `npm login` on this machine
   - [ ] The `@minidoc` scope exists and you can publish to it
   - [ ] You publish the editor 0.1 (`@tilia/editor`, `@epure/editor`) before minidoc is pushed
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