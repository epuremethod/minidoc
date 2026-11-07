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
4. [/] **The plan, moved into minidoc** waiting: commits
   - [x] maia's PlanView rework is a hand-made copy: stage 4 replaces it
   - [x] a. Intention agreed: edited in place by live, long layout; a text shows markdown only under the caret; an edit changes only what it touches; a source switch until stage 5
   - [x] b. Testing agreed: edits.test.yaml (15), marks as fields, editing.test.yaml (13), maia's edit scenarios move here; an empty todo reads as empty
   - [x] c. Technical agreed: edits in blocks on the touched characters, the drawing names its clicks, live draws inputs, the plan an ordinary block in maia
   - [x] d. Built: `pnpm check` passes (blocks 123, live 41); maia 277; app rebuilt
   - [x] Untick fixed; audit of the old plan: input-method Enter and Escape fixed
   - [x] You tried it in maia: unticking works
   - [x] Real-Chrome hit check: `pnpm live:hit`, 254 places, run at the end of every build
   - [x] Texts edited as you see them: agreed, both sides at once
   - [x] Text field tests agreed: the box's 16 stay, 7 with a stand-in, 2 hit cases
   - [x] Every text is an editor line with no look of its own, checked in Chrome to look like the page
   - [x] Nina 3 built the slot in live: 442 clicks and 74 texts that look the same
   - [x] Enter splits a todo; a ticked todo's halves stay ticked; adding a todo to a done stage moves it back (blocks 129, live 50)
   - [x] editor-36 built `TiliaEditor.Line` (editor 5bdbe7f) and the shadow-root fix (e893c45)
   - [x] The plan's texts are editor lines in maia; app rebuilt; maia now belongs to maia-cf
   - [x] maia-cf added a crash  **foo**guard around each block (approved, separate commit)
   - [x] You tried the bold-Backspace crash: the guard shows "this block failed" and the notes go on
   - [x] The editor fixed the caret after `**` in a shadow root, and the bold-Backspace crash (editor 7a681d8)
   - [x] maia rebuilt with the fixed line (329 tests)
   - [x] Nina 4 reran the checks on the fixed line: both cases fixed in Chrome, 442 clicks and 74 texts, `pnpm check` green
   - [x] Calmer stage list agreed (a, b, c): number and title on one line, state mark at the right, message below, no counts, one third wide, band too
   - [x] Nina 4 built it: band without mark, wider columns (blocks 129, live 51; 450 clicks, 74 texts, 12 widths)
   - [x] You tried it in maia: it works
   - [x] e. 11 decisions in DECISIONS.md, changelog, SESSION.md cleared
   - [ ] Commits when you ask (minidoc: me; maia: its session)
5. [ ] **Flows, screens, API calls** intention → tests → technical → build → next
   - [ ] Their fields become inputs in live, with the single-line editor
   - [ ] maia: a click selects the block and shows the source in the editor's pane
6. [ ] **Callouts' prose** intention → tests → technical → build → next
   - [ ] Kind, title and byline as fields
   - [ ] Prose: an editor nested in the block (2–3 d), or blocks that hold blocks in the editor core (1–2 w)
7. [ ] **Diagrams** intention → tests → technical → build → next
   - [ ] Sequence, states, model: source with live re-layout, a click jumps to the line
8. [ ] **Prepare the versions**
   - [ ] Versions for core, blocks, the live package and `@epure/minidoc`
   - [ ] maia's docs move to the published blocks
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