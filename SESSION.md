# Session

Step 1 of the session fills **Intention**, step 3 fills **Technical**. When
the session closes, any choice worth remembering is appended to
`DECISIONS.md` and this file is cleared back to exactly what you are
reading. See `CONTRIBUTING.md`.

## Handoff (2026-11-14, end of the croquis session: steps 4 and 5, the changelog)

Read this first. Then the Live page of the docs,
`packages/docs/content/live/03-gently.md` ("Level 2: components", steps
4 and 5, "What tilia's and radif's websites need", "A changelog"), the
blocks' `packages/docs/content/blocks/04-changelog.md`, the last entries
of `DECISIONS.md`, and the plan in maia (stage 5, "The croquis").

### How the owner works (this session)

- Docs-driven: the website is the channel. Write the lesson on the docs
  page first, as if teaching it, then the fixtures, then the code.
- Convention over configuration. Frontmatter holds config or globs.
  `index.md` maps to `index.html`. Folders: `images/`, `assets/`,
  `components/`. A site writes no ReScript component.
- No code before "You can build" (a click on a note's button says it).
  One question or proposal per maia note. Write in ASD-STE100.
- The plan tool takes a todo as `[x]` or `[ ]` only, never `[/]`.

### The croquis: steps 1 to 5 are built and recorded

`minidoc <folder>` is a new core in `packages/core/src2/`. `pnpm dev` at
the root runs it on `packages/core/croquis/`. A global shim,
`~/.local/bin/minidoc`, runs `packages/core/src2/cli.mjs` from any
folder; tilia-14 uses it for the notes of tilia's bug.

- Step 4, images: an image line is an `image` atom (editor's
  `Page.res`, handed to editor-af); paste writes `images/<page>-<n>.png`;
  a rename in the image's pane moves the file and rewrites every link;
  a change on disk draws it again. `@minidoc/live/edit` draws an image
  line as an `<img>`.
- Step 5, components: `<x data-component="name">` in `index.html`;
  `<nav>` is `menu`; minidoc gives `contents` and `menu`;
  `components/<name>.jsx` (default export) adds or replaces one; props
  `{page: {title, href, headings: [{level, text, slug}]}, pages}`; an
  unknown name is refused; a heading's link is its GitHub slug, and the
  client leads it to the heading's block. Files: `Outline`, `Part`,
  `Contents`, `Menu`, `Render`, `Client`, `Article`, `parts.mjs`,
  `serve.mjs`, `Site.isComponent`, `Sync`.
- Callouts in the croquis (`src2/editor.css`): the kind is a small word
  floated top right with no box; the byline takes a line only when it
  holds something or the caret is in the callout (`data-caret`, set by
  the client); no margin before the first block or after the last.

### The blocks

- Dark mode: each theme colour is `light-dark(light, dark)`; a page that
  declares `color-scheme: light dark` gets dark blocks (DECISIONS).
- The blocks chapter is in alphabetical order, "The package" first,
  "Errors" (was "The strict check", `13-errors.md`) last.
  `10-contracts.md` is now `05-contracts.md` (AGENTS.md follows).
- The changelog (DECISIONS, two entries): `CHANGELOG.md`, `- YYYY-MM-DD
  **X.Y.Z**`, `- Unreleased` first, each change led by Add, Change, Fix
  or Remove, a breaking one ended by `**Breaking**`. `::: changelog` and
  `::: release` are built in `@minidoc/blocks` (`Changelog.res`), inline
  or from a file by a path relative to the page, read through a new
  `read` option `(path, page)`. Core now gives each transform
  `page.file`; live maps `datetime`; the docs plates take a scenario's
  `files`. The docs site gives no `read` (its options run in the
  browser too).

### Checks at the end

Blocks 190, live 76, core 173 and 32 dev, docs 3, `pnpm docs:edit-check`
16, croquis fixtures 39 and `node packages/core/test2/chrome.mjs` 21.

### Waiting for the owner

- gdos has the new build (`pnpm install` done after the owner stopped
  its server). The owner restarts it (`cd ~/git/vs/gdos && pnpm
  docs:dev`), types a word in `screens.md`, and then a save is checked by
  the file's mtime.
- tilia's `minidoc notes` server started before step 5: it needs a
  restart for the new client (CSS is read from disk at once).

### Other sessions

- editor-af: told of the image change in its `Page.res` (7 scenarios).
- tilia-14: has the `minidoc` command, the changelog format (with
  `**Breaking**` at the end) and the blocks. tiliajs.dev stays on
  `@epure/minidoc` 0.1.1 with its own transform until croquis step 9.
  The owner wants the croquis finished before it replaces
  `@minidoc/core`.

### Next

1. Step 6, docs first: sections (a page made of several files),
   frontmatter, sub-folders, a slug for each section.
2. The croquis's `release` and `changelog` components (`data-file`), and
   a `read` for the changelog block in the croquis.
3. Steps 7 to 10: a template for each kind of page; code in colours and
   tilia's TypeScript and ReScript pair; the build, redirects and
   `llms.txt`, then tilia moves; YAML pipelines and the site's own
   blocks, then radif moves.
4. In the plan, stage 12 says "a transform's page gains file" is
   breaking: it is not (an optional field). Fix that todo.

### Pitfalls

- A headless Chrome screenshot of `docs/dist/*.html` by `file://` is
  blank: shoot the docs dev server instead (port 54714 today), through
  the DevTools protocol, as `packages/core/test2/chrome.mjs` does.
- The docs dev server runs (`packages/docs`, `node src/dev.mjs`): after a
  rename of content files, reload the open pages.
- A croquis server started earlier keeps its old client and server code.
- Nothing is committed: about 185 paths here, and work in `~/git/editor`,
  `~/git/tilia`, gdos, radif, maia and nine `~/git/vs` projects.

### Other open notes

- Note 44 (a page outside dev stays static, never prints): not answered;
  in the plan under "Fix bugs".
- Notes 48 (React layout), 50 (one carved site), 51 (ReScript): older
  design proposals, superseded in part by the croquis; not answered.

## Handoff (2026-11-12, from the session that ends here)

Read this first, then the plan in maia (`.maia/notes.md`, stage list
"Publish 0.2.0") and the last entries of `DECISIONS.md`.

### Nothing is committed

About 155 changed paths in this repo, and uncommitted work in
`~/git/editor`, `~/git/tilia`, gdos, radif, maia and nine `~/git/vs`
projects. The owner commits only when asked: one line, present tense, no
body, no trailers, one commit per feature.

### Waiting for the owner now

- **Note 40, "A failed save must stop you"**: built (see `DECISIONS.md`,
  2026-11-12). Three Chrome checks cover it. gdos has it.
- **Writes from `*.local`**: built (see `DECISIONS.md`, 2026-11-12). The
  owner opens gdos at `http://a.local:54443`. gdos has it.
- **A copied table loses its header**: in the editor's
  `Clipboard.blocksSlice`; handed to editor-af with a reproduction.
- **gdos's dev server** (port 54443, started 13:46 with the old code)
  cannot save. The owner must restart it: `cd ~/git/vs/gdos && pnpm
  docs:dev`. Then check that an edit on the page changes the file's mtime.
  `model-fr.md` was restored from the owner's copied text; the version
  that was on disk before is in this session's scratchpad
  (`model-fr.before-restore.md`).

### Done in this session, uncommitted

- **Packages moved to `@minidoc`** (owner's decision): `packages/core` =
  `@minidoc/core` (was `@epure/minidoc`), `packages/blocks` =
  `@minidoc/blocks`, new `packages/live` = `@minidoc/live` (Live, Pane,
  `live.css`, and the page editor `@minidoc/live/edit` with `edit.css`).
  All at 0.2.0. Suffix `.mjs` everywhere (was `.res.mjs`). Tilia's
  packaging pattern: `src` whole, `dist` by esbuild from `src/index.js`,
  hand-written `index.d.ts`, clean-package. `pnpm pub <core|blocks|live|all>`.
  Core moved to sury 11.1.0. A package test packs all six tarballs.
- **Editor repo** (`~/git/editor`, owned by the editor session):
  `.mjs` suffix in its four packages; `@epure/editor` and `@tilia/editor`
  packaged like tilia (suggested 0.1.0-beta.3). Its DECISIONS entry was
  handed to the editor session, not written.
- **Tilia repo**: `react/.npmignore` re-includes `src/*.mjs`, so
  `@tilia/react` ships `TiliaReact.mjs`. Needs a 6.0.2 release first.
  A consumer build once rewrote the tracked `react/src/TiliaReact.mjs`
  with a stale `tilia/src/Tilia.res.mjs` import; `git checkout` fixes it.
- **Consumers on `@minidoc`**: gdos, radif's website, maia app and docs,
  and ADJ, AIAD, ECM-DCE-DPT, ERP, FUSION, memovs, PROJ, SWISSID, VM.
  gdos, ADJ and FUSION use `file:` copies (one React and one tilia), so a
  minidoc change needs `pnpm build` here, then `pnpm install` there.
  maia links `../../tilia/react` until 6.0.2; maia's pane hides
  `.pane__colours` (no syntax colours there yet).
- **Blocks**: every word in braces holds spaces and takes `color`
  (columns, labels; a coloured label draws its line); a model column's
  type in `--tone-principle`; coloured text mixes toward the ink by
  `--drawing-ink-amount` (80%); `blocks/test/themes.test.yaml` checks that
  each theme sets every variable and that `05-contracts.md` and llms.txt
  name each one; `::: comment` (label "Comment", `--tone-comment`,
  `Blocks.removable`, no label, a one-line head with an icon, as wide as
  the text, shifted right by `--comment-shift`), its × in edit mode
  (editor's `~removable` prop); model groups `--- name` (an ancestor's
  name takes its table's hue; a first group has no line; an empty group
  is refused).
- **Edit mode**: a block selected whole shows an outline in
  `--tone-ui-clicked` and no text highlight; the Chrome checks open a
  source with two clicks.
- No `bold` attribute (refused, recorded).

### Checks at the end of the session

`pnpm check`: core 134 + 31 dev, blocks 177, live 73, docs 3, package
test passes. `pnpm docs:edit-check`: 12 Chrome checks pass (run before the
model groups; run again).

### Next, in the plan's order

1. Note 40 (save alert), then restart gdos's server and check a save.
2. Follow-ups of the move: maia's pane colours; the editor's docs on
   `@minidoc` (editor session); deprecate `@epure/minidoc` on npm.
3. Docs gaps from the release review: guide "Editing the page", an API
   page for `@minidoc/live`, the `:::` breaking change, `lang: ts` in API
   pages (rename to `signatureLang`), port range, `X-Forwarded-Prefix`,
   blocks JavaScript API page, Live page for a React host, states kinds,
   flows and screens opening lines, `#` comments; llms-full without plate
   wording; READMEs for blocks and live.
4. Changelog: rename "Unreleased" to 0.2.0; remove the old double-quote
   and `{active a b}` entry; list every breaking change.
5. `DECISIONS.md`: tables are edited in place, not in the panel.
6. Commits (owner asks), then publish in order: `@tilia/react` 6.0.2,
   `@epure/editor` and `@tilia/editor` 0.1.0-beta.3, then
   `@minidoc/blocks`, `@minidoc/core`, `@minidoc/live`. A beta first,
   tried on gdos. The owner runs `npm login` and publishes.
7. Later: dark mode.

### Pitfalls

- Never change packages under a running dev server without telling the
  owner to stop editing and restart it: saves fail silently today.
- Other Claude sessions work in the sibling repos (editor-af, tilia-14,
  gdos-d7, radif-5e, maia-3f). Tell them before an agent edits their
  repo, and keep off their files.
- After a suffix change, stale ReScript caches (`lib/`) keep old import
  paths; clear them, but do not run a `rescript clean` that reaches the
  linked editor packages while another session builds there.
- `@epure/vitest` drops " the " from step names: avoid "the" in them.
- Questions and proposals go in maia notes; the plan with the maia
  "plan" tool; write to the owner in ASD-STE100.

## Intention

A croquis of the next minidoc, so the design of the Live page
(`packages/docs/content/live/`) is tried before anything else is
rebuilt. It serves a person who points minidoc at a folder of markdown
files and wants to read and edit them, with no config.

`minidoc <folder>` serves each `.md` file of the folder as a page, with
a sober default template, a menu of the pages, and the editor on the
text. The editor is the only render: its view with editing off at
build, the same view hydrated in the page. A key in the page writes the
file; a save of the file by another program lands in the page, merged.

The croquis is a new core in `packages/core/src2/`, with nothing of
`src/`. `pnpm dev` at the root runs it on `packages/core/croquis/`, a
folder with one markdown file. Step 1 is level 0 only: no `index.html`
of the folder, no map of the site's own.

## Technical

Settled with the owner (2026-11-13), as croquis choices that can change:

- The static HTML is the editor's view as it is, with editing off.
- A page carries the files its render read, as JSON in a
  `<script type="application/json">`; its state starts from them.
- Islands: one React root for each element of the map (`article`,
  `nav`); a tilia `observe` writes `document.title`.
- `pnpm dev` runs under `node --watch`; a change to `src2` restarts it
  and reloads the pages; a change of a file of the folder lands through
  the sync.
- ReScript, compiled to `.mjs`. A WebSocket through `ws`. `linkedom` for
  `querySelector` in Node. The default template is a built-in
  `index.html` and stylesheet in `src2`, filled by the same map as a
  folder's own.
- The sync carries files: a path, a version, a text. A save names the
  version it starts from; a stale one is refused with the file that
  stands, and the page merges it with `View.land`.

## Intention (2026-11-16): a file lands with the editor's ids

Built on 2026-11-16, not committed.

A person edits a page while another program saves the same file. The
file lands in the page and merges with what the person typed. Today
the croquis gives ids to a landed file in its own `Land.against`. It
keeps block ids, but it numbers atoms (drawings, images) by their order.
A drawing added before another takes the other's id. Since the editor's
commit da2dfc7, `Page.read ~base ~mint` keeps the ids of blocks and
atoms. The croquis uses it, and `Land.against` goes. The scenarios are
in `packages/core/test2/land.test.yaml`.

## Technical (2026-11-16): a file lands with the editor's ids

Checked in a scratch script against the compiled code:

- `Page.read ~base ~mint` (editor `Page.res:854-1007`) keeps an atom
  whose format and value stay, then keeps block ids with
  `Identity.read`. It keys `blocks` by these ids, so nothing is renamed.
  It takes the section id and `uses` from `base`, and gives `rules` and
  `spelt`. It covers all of `Land.against`.
- A real fault today: `Land.mjs` was compiled before `rules` and `spelt`
  existed, so `Land.against` drops them. `Page.write` then throws
  "reading 'formats'" on the first save after a landing.
- A real fault by design: `Land.against` numbers atoms by order, so the
  merge can keep a typed drawing under the id of a new one.
- `spelt` is filled only for `~formats` and `~notations`. minidoc passes
  none, so `{{x}}` stays text and writes back as it was. No loss today.
- `Land.merge` stays. It is a copy of `Sections.merge` in `@radif/editor`,
  which minidoc does not depend on.
- `Article.read` keeps `Land.read` with no base: a first read.

Settled with the owner:

- minidoc passes no `~formats` and no `~notations`.
- The `rescript build` of this work fixes the throw; no separate fix.
- `Land.merge` stays as it is.
- The editor version requirement stays: `@minidoc/live` asks for
  `^0.1.0-beta.3`, and the editor packages are at beta.2, unpublished.
  The release needs a beta.3 that holds da2dfc7.

Open: ask the editor to export a merge, so `Land.merge` goes too?

Steps of the build, all done:

1. [x] `a landing` is bound in `packages/core/test2/steps.ts`. The 7
   scenarios failed: 6 threw "reading 'formats'", and the drawing
   scenario gave the wrong ids.
2. [x] `Land.against` calls `Editor.Page.read ~base ~mint` and nothing
   else. `renamed` is gone.
3. [x] `Article.res` is unchanged.
4. [x] `rescript build`, then core 180 pass (7 new), dev 32 pass, live
   76 pass, `test2/chrome.mjs` 21 pass.
5. [x] Not needed: the Chrome check "a word typed in one block and a
   change on disk to another both stay" saves after a landing.

## Intention (2026-11-16): the croquis page on the editor's Markdown engine

Built on 2026-11-16 on the editor's bf3eada, not committed. The owner
tests it in ci-scan before a commit.

The croquis page held its own engine around the editor's `Page`:
`Article.res` kept the file, the agreed section, the pause and the
landing, and `Land.res` merged. The page now uses the editor's engine
for one markdown text, `TiliaEditor.Markdown`: the view's state, the
pause, the text, `land` with a three-way merge, `flush`, and the
frontmatter. minidoc keeps only what is its own: the sync messages and
their versions, images and paste, the outline, the components, the pager
footer, and the reload fix of `Channel`.

## Technical (2026-11-16): the croquis page on the Markdown engine

Done:

- `Land.res` is removed (59 lines). `Article.res` loses 61 lines and
  gains 34: `Markdown.make` with `engineOptions` (kinds, blocks, rules);
  `onChange` sends a save on the version the page holds; `file` and
  `stale` call `notes.land`; `saved` sends again when the text moved on;
  a reload runs `notes.flush()`; an unmount runs `notes.close()`.
- The engine adds the editor's markdown shortcuts (`# `, `- `, a callout)
  by default: the croquis did not have them.
- The frontmatter: not drawn, kept byte for byte, merged key by key on a
  landing. No FrontFields is shown: croquis step 6 decides what the page
  shows of it. The Yaml encoder resolves `yaml` from the editor's own
  `node_modules`.
- Tables: the editor reads and edits them in place, with no rule.
- `land.test.yaml` drives the engine (`a landing` in `steps.ts`): an id
  the agreed text lacks is `new`, atoms compare in any order, and the
  engine's pause is longer than a scenario, so what is typed is not given
  yet. 3 new scenarios: words merged in one block, a frontmatter kept
  through a landing, a frontmatter value landed beside a typed block.
- `folder.test.yaml`: a table drawn with its header, the frontmatter not
  drawn. `chrome.mjs`: a table cell edited in place, the frontmatter kept.
- Checks: core 187, dev 32, live 76, `chrome.mjs` 24.

Done after editor-20's `land(text, ~base)` (editor working tree over
bf3eada, not committed there yet):

- `Article.res` lands each file over the text the server held before it
  (`held.written`): a save the disk made stale keeps its words.
- `land.test.yaml`: "words the page sent in a save that the disk made
  stale stay when the disk's text lands" (`sent: true`), seen failing
  without the base. Checks: core 188, `chrome.mjs` 24.
- No Chrome check for a stale save: forcing the race needs a disk write
  inside the 300 ms pause after the server's version moved, too fragile.
- minidoc needs the editor to commit `land ~base` before a minidoc
  commit.

Left:

1. The owner tries ci-scan after a restart of `pnpm docs:dev`.
2. Commit, one commit, when the owner says.
3. Croquis step 6: what the page shows of the frontmatter (FrontFields
   or none).

## Intention (2026-11-16): croquis step 6, a page of several files

Built on 2026-11-16, not committed. Recorded in `DECISIONS.md` (two
entries) and on the Live page ("Step 6 is built").

tilia's website is the first real site for minidoc v2. Its Guide is one
head and thirteen chapter files, and its API has one file for each
entry, in sub-folders. Its templates read frontmatter values, and its
text uses three callouts of its own: `story`, `pro` and `def`. Step 6
gives the croquis these three things, together. It serves a person who
writes tilia's guide and edits one chapter in the page while agents
change other files. The Live page teaches it first: "Step 6: a page of
several files" in `packages/docs/content/live/03-gently.md`.

## Technical (2026-11-16): croquis step 6

Conventions chosen (proposed on the Live page):

- A head file names its sections with `sections:` in its frontmatter,
  one glob or a list. A glob is relative to the folder, with `*` in one
  folder. The files of each glob are in file-name order; the globs are
  in turn. A glob that names no file gives no section.
- The section's slug is its file name without the number and `.md`.
  `slug` and `sort` in the frontmatter change nothing.
- The section's title is its first heading (as proposed on the A page
  page), or else its slug. `nav` in the frontmatter is a short label,
  for a page and a section.
- A section is `<section id="slug">` in `<article>`, after the head's
  text. Its title heading takes no slug of its own; `contents` links it
  to the section. Heading slugs stay unique over the whole page.
- A markdown file at any depth is a page, unless a page names it as a
  section. A page in a sub-folder gets links and stylesheets relative
  to it. A file named by two pages is refused.
- `data-front="key"` in the template shows the page's value: a text, a
  number, a date, a yes or no. A missing key, a list or a map leaves
  what the template wrote. A key is read whole (`signature.ts`).
- Components get `page.front`, `page.sections` (file, slug, title,
  nav, front) and `front` on each page of `pages`. The page carries
  them, with each section file, for its hydration.
- The frontmatter shows no fields in step 6. A change on disk lands.
- A site names its callouts in its template: `<meta name="callout"
  content="pro Pro tip">`, the name and then the label. They go to
  `Blocks.callouts` (`options.callouts`), so the editor draws them and
  live knows them. A name that is a block of minidoc is refused.
- One editor engine for each file of a page. A save names its file. A
  new block at a section's end stays in that file. A new section is a
  new file.
- The sync: a section file is not a page. `pages` carries each page's
  sections, and goes again when a section's title, a glob, or a file
  that a glob names changes.

Rejected: one editor over the whole page, split into files on save (the
editor has no such engine, and a border block has no home); `slug` and
`sort` in the frontmatter (they repeat the file name); the callouts in
the head's frontmatter, a `callouts/` folder, or a config file.

What the editor gives at febb75b, read, not changed:

- `TiliaEditor.Markdown` is one engine for one text, with `json` (the
  frontmatter, read by an injected encoder) and `front`. One engine per
  file is enough for step 6.
- `FrontFields` draws the frontmatter as labelled inputs
  (`MarkdownField.res:61`). Not used in step 6.
- No engine for a page of several texts, and no hook for the caret to
  leave a view at its first or last line (`onLeave` is for atoms only).
  A caret that crosses sections needs that hook: asked later, not
  needed for step 6.
- The `Rule` block form in the editor's working tree is not used.

Built:

- `Site`: `pagesOf` (sections, slugs, `front`, `nav`, the refusal),
  `relative` and `rootOf`. `Outline`: the headings of each file, and
  `page`, which gives the slugs over the whole page.
- `Body` is the island of `<article>`: the head's `Article`, then one
  `Article` in a `<section>` for each section. `Article` takes a `kit`
  (the site's callouts), a `prefix` for its block ids, and opens its own
  file on the channel.
- `Render`: `calloutsOf`, `data-front`, links relative to a page in a
  sub-folder. The page carries `root`, `outline` and `callouts`.
- `Sync`: a page shows several files; the pages go when anything of them
  changes; a refused folder keeps the last pages (`refusal`).
- `Client`: on `pages`, it asks for a section file it lacks (`opens` on
  version 0) and the section shows when the text comes.
- `serve.mjs` reads markdown at any depth, but not `node_modules` nor a
  name that starts with a dot.

Changed in the fixtures: one selector, `.callout--pro
p:not(.callout__byline)`, because the byline is the callout's first
`<p>`. `chrome.mjs` gives each server its own port: two servers took the
same random port once.

Checks: core 213 (25 new), dev 32, `chrome.mjs` 30 (6 new). Not run
again: live, blocks, docs, `pnpm docs:edit-check`. This work did not
change their code.

Left:

1. The owner tries a page of several files, then says when to commit.
2. An element with `data-front` keeps its last value when its key
   leaves the frontmatter, until a reload.
3. tilia's chapters take their title as a first heading before the move
   (step 9).
4. The caret crossing two sections: ask the editor for the hook.
