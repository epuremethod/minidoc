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
7. [/] **Callouts in place** tried: ready to commit
   - [x] a. Intention agreed: one editor for the page; a callout is a start block plus blocks marked as in it; the view draws the frame
   - [x] `::: kind` and space makes a callout, caret in its author; Tab to the date, then the body; Shift-Tab back
   - [x] The frame: no title of its own, the kind from the label, author and date in place, quotes too, maia's notes too
   - [x] The editor's session builds callouts in the editor (editor 41320d8)
   - [x] The editor's session commits `Block ~tag`, code spans with a backtick, the prefix fix (editor 16900d9)
   - [x] minidoc drops its block-id workaround (minidoc dd5c306)
   - [x] minidoc gives the editor its callout kinds and labels
   - [x] minidoc reads a `:::` callout as a start and its rows, and writes it back
   - [x] The callout's head and byline styled in edit.css; a Chrome check types one
   - [x] You tried it on the dev page: it works
   - [ ] Commit in minidoc
   - [ ] maia's session follows
8. [/] **Code blocks in place** built: you try it on the dev page
   - [x] The editor's session builds code blocks in the editor (editor 30cb1d4)
   - [x] minidoc reads a fence that is not a drawing as a code row, and writes it back
   - [x] A code block in a callout keeps the callout in place
   - [x] The language field styled in edit.css; a Chrome check types one
   - [ ] You try it on the dev page
   - [ ] Commit in minidoc
9. [/] **Prepare the versions** renamed: minidoc 7badccf
   - [x] The names agreed: `@epure/minidoc` with `/edit`; `@epure/blocks` with `/live`; the editor and React as optional peers
   - [x] The rename agreed: `packages/minidoc` and `packages/blocks`; live, edit and deprecated go; existing tests moved
   - [x] Nina 6 built the rename: minidoc 139 + 28 dev, blocks 181, docs green, Chrome checks unchanged
   - [x] maia's session follows the new names (354 tests, uncommitted)
   - [ ] Versions for `@epure/minidoc` and `@epure/blocks`
   - [ ] maia's docs move to the published blocks
   - [ ] Changelog: "Unreleased" gets the release date
10. [ ] **Get npm access** needs you
   - [ ] `npm login` on this machine
   - [ ] You can publish to the `@epure` scope
   - [ ] You publish the editor 0.1 (`@tilia/editor`, `@epure/editor`) before minidoc is pushed
11. [ ] **Publish**
   - [ ] `pnpm pub minidoc`, then `pnpm pub blocks`
12. [ ] **Ship**
   - [ ] Push main and the tags; the docs deploy to GitHub Pages
   - [ ] Install the packages in a scratch project and build a page
   - [ ] Move radif, vs/* and muse to `@epure/minidoc` and `@epure/blocks`
:::

## hello
_what_ is **this** ?