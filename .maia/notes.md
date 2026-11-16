::: plan Publish 0.2.0
1. [x] **Packages: @minidoc scope and tilia's pattern**
   - [x] @tilia/react ships its compiled src
   - [x] Suffix .mjs in editor, @tilia/editor, pen, radif
   - [x] @epure/editor and @tilia/editor: tilia's pattern, license, README, public access
   - [x] Suffix .mjs in minidoc and blocks
   - [x] @epure/minidoc becomes @minidoc/core
   - [x] @epure/blocks becomes @minidoc/blocks
   - [x] @minidoc/live: Live from blocks, and the page editor from core
   - [x] Each minidoc package: compiled src, dist, index.d.ts, clean-package
   - [x] Peers on the published versions, no link: in the manifest
   - [x] Package test from tarballs
   - [x] gdos, radif, maia app and docs, and nine vs projects on @minidoc
2. [x] **A comment callout**
   - [x] comment kind, --tone-comment, Blocks.removable
   - [x] The × in the editor, and minidoc passes removable
   - [x] As wide as the text, shifted right, one-line head with an icon
   - [x] gdos colour and a test comment
3. [x] **Groups in a model table**
   - [x] --- name groups properties; an ancestor takes its hue
   - [x] A group first shows its name with no line; an empty group is refused
   - [x] A group's name under its line, at the right, larger and light grey
4. [/] **A failed save stops you** restart gdos
   - [x] A banner that stays until a save succeeds, with Copy my text and Retry
   - [x] A warning before leaving with unsaved edits
   - [x] A draft in the browser, offered after a reload
   - [x] A conflict banner in place of a reload when the file changed
   - [x] Chrome checks
   - [x] gdos on the new build
   - [x] gdos restarted, and a save checked by the file's mtime
5. [/] **The croquis: minidoc on a folder** step 6 built
   - [x] Step 1: pages, default template, menu, the editor's view hydrated
   - [x] A sober default style for long reading and writing, light and dark
   - [x] Step 2: the sync through a socket, merged by View.land
   - [x] Step 3: index.html fills article, nav and title
   - [x] Step 4: image lines, paste, rename and redraw (16 Chrome checks pass)
   - [x] Step 4: an image line drawn in @minidoc/live/edit
   - [x] Step 4: recorded on the Live page
   - [x] Callouts: the kind a small word at the top right, the byline only when needed, no extra space
   - [x] Step 5: data-component, components/*.jsx, contents with slugs (21 Chrome checks pass)
   - [x] The changelog format: CHANGELOG.md, a kind for each change (settled)
   - [x] Step 6: sections, frontmatter, sub-folders, callouts of the site (30 Chrome checks pass)
   - [ ] data-front: a key that leaves the frontmatter restores the template's text
   - [ ] The caret crosses from one section to the next (needs a hook of the editor)
   - [ ] The release and changelog components, and a read for the changelog block
   - [ ] Step 7: a template for each kind of page
   - [ ] Step 8: code in colours, tilia's TypeScript and ReScript pair
   - [ ] Step 9: the build, redirects, llms.txt; then tilia moves
   - [ ] Step 10: YAML pipelines, the site's own blocks; then radif moves
   - [ ] A block whose id changes keeps the words typed in it meanwhile
   - [ ] Live splits a drawing's HTML without a document
   - [ ] The editor draws plain HTML: no zero-width spaces, ids or contenteditable when static
   - [ ] An image inside a sentence
   - [ ] A drop of an image
6. [ ] **Follow-ups of the move**
   - [ ] maia's pane: syntax colours outside the shadow root
   - [ ] editor/docs on @minidoc (editor session)
   - [ ] Deprecate @epure/minidoc on npm, naming @minidoc/core
7. [ ] **Guide and API**
   - [ ] Editing the page: edit option, mount, clicks, typed blocks, autosave, reloads
   - [ ] API page for mount and @minidoc/live
   - [ ] Every block starts with :::, explained, with the full list of blocks
   - [ ] (text, page) marked as breaking in the guide
   - [ ] dev: random port range, X-Forwarded-Prefix, 400 and 405, a running server
   - [ ] Braces typed on the page are escaped
8. [/] **Fix bugs**
   - [x] Blocks follow the page's colour scheme, with light-dark()
   - [ ] A copied table loses its header, each row alone (editor-af has it)
   - [ ] API pages set lang to ts: rename to signatureLang
   - [ ] dev comment in Minidoc.resi about the port
   - [ ] A write through a proxy on another origin gets 403
   - [ ] A page outside dev stays static, and the editor never prints (gdos print)
9. [/] **Blocks docs**
   - [x] Blocks in alphabetical order, The package first, Errors last
   - [x] Changelog: the format, ::: changelog and ::: release, with their plates
   - [ ] JavaScript API page: read, write, draw, render, edit, keys, callouts, options
   - [ ] Live page for a React host: props, token classes, an example
   - [ ] States: kinds, label kinds, legend, caption, places
   - [ ] Sequences and models: the attributes each name takes
   - [ ] Flows and screens: their opening lines, with an example
   - [ ] Comments with # in the drawings
10. [ ] **llms.txt and llms-full.txt**
   - [ ] No plate wording in llms-full
   - [ ] A description for each blocks page
   - [ ] Links to the API and Live pages
11. [ ] **READMEs**
   - [ ] @minidoc/blocks: install, CSS, themes
   - [ ] @minidoc/live: install, React, the page editor
12. [ ] **Changelog for 0.2.0**
   - [ ] Heading with the version and date
   - [ ] Current syntax in place of quotes and {active a b}
   - [ ] Breaking: :::, label places, tenant classes, --hue-*, textarea.pane__source
   - [ ] Missing entries: port, prefix, tables in place, card, pane colours, type colour, comment
   - [ ] minidoc's own changelog in CHANGELOG.md, in the settled format
   - [ ] Breaking: a transform's page gains file; the changelog and release blocks are new
13. [ ] **Records**
   - [ ] DECISIONS: tables are edited in place, not in the panel
   - [ ] DECISIONS: components by data-component
14. [ ] **Commits and push**
   - [ ] tilia, editor, minidoc and each consumer: one commit per feature
15. [ ] **Publish**
:::

## hello
_what_ is **this** ?