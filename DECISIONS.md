# Decisions

Append-only, at the end, and never edited. An entry is an account of a moment,
not a description of the system, which is why it cannot go stale. To reverse a
decision, append a new entry naming the one it supersedes.

An entry gives the date, the choice, the alternative refused, and what the
choice costs, when there is a real cost. If it cannot name an alternative, it
is not a decision: leave it out. Keep it short. The reader is as smart as the
writer.

The first entries were carried over from the README and the code comments,
where these choices were made before this ledger existed. Their dates are the
day they were written down here.

## 2026-10-03: Input and output are injected

The core reads and writes only through the `filesystem` it is given.
Transforms are given too.

Refused: importing `node:fs` and `node:path` in the core. The tests could
then not run on an in-memory filesystem, and minidoc could not load in a
browser.

Costs: a custom filesystem implements every method, and a new one breaks it,
as `listDirs` did in 0.2.0.

## 2026-10-03: A rebuild with a build script runs in a fresh process

When `watch` or `dev` has a `build` script, each rebuild spawns it in a new
Node process.

Refused: calling `run` again in the same process. Transforms reach `run` as
closures, and the ESM cache never hands back a module whose file changed, so
an edited transform would not take effect.

Costs: one process start per rebuild. Without a `build` script, `dev` runs in
its own process and does not see a transform edit.

## 2026-10-03: The watcher is Node's recursive `fs.watch`

Refused: a watcher library. minidoc requires Node 22, whose `fs.watch` is
recursive on macOS, Windows and Linux, so a library would add a dependency
for nothing.

Costs: editor noise is filtered by hand: dot-names, backup files ending in
`~`, files with no known extension, and the output folders.

## 2026-10-03: A run updates outputs in place

A run writes each declared output over the old one. It never cleans the
output folder first.

Refused: cleaning before writing. A live server would then serve missing
files until the run ends.

Costs: an output that is no longer declared stays in the output folder until
someone removes it.

## 2026-10-03: Two outputs on one path fail before anything is written

Every output path resolves first. Two outputs on the same path fail loud and
name both. Copies into one directory merge and are exempt.

Refused: last write wins, which 0.1 did. A page could silently replace
another one.

## 2026-10-03: A file var's frontmatter is read under the var's name

`{{intro.title}}` is the `title` of the file that `intro` loads.

Refused: merging a file's frontmatter into the context that declares it,
which 0.1 did. Two files with the same frontmatter name then conflicted, and
a rule had to say which one won.

Costs: 0.1 configs that read a file's frontmatter by its bare name break.

## 2026-10-03: Layers merge leaf by leaf, and a group's kind is read after

A var block or a frontmatter block nests. Layers merge one leaf at a time, so
a page can override `layouts.cv` and keep `layouts.letter`. A group becomes a
`file`, `dir` or other kind only after every layer has merged.

Refused: a layer replacing a whole group. A page would then have to repeat
every key it does not change.

Costs: reading a plain group as a whole fails loud.

## 2026-10-03: The Node filesystem is fenced to its root

Every read, write, copy and listing stays inside the root, or inside a folder
listed in `allow`. Anything else fails loud.

Refused: free access. Paths are templates that content can steer, so a
page's frontmatter could publish `~/.ssh/id_rsa` or write outside the
project.

Costs: a site that uses content outside its root lists that folder in
`allow`. The check is on the path as written; symlinks are not followed.

## 2026-10-03: `dev` never replaces a taken port

When the port is taken by a minidoc dev server, `dev` prints its link and
returns. When anything else holds it, `dev` fails loud.

Refused: drawing a free port and writing it to the config, which 0.2 betas
did. The site's address then changed without anyone asking, and a second
launch of the same site started a second server.

Costs: a port held by another program stops `dev` until the port is freed or
another one is passed.

## 2026-10-03: Common blocks live in their own package

`@epure/minidoc-blocks` gives every site the same `:::` blocks through one
transform. minidoc's core stays unaware of any markdown dialect.

Refused: blocks inside minidoc's own `md` transform. Every site would get
them whether it wants them or not, and the core would carry markdown-it
beside marked.

Costs: a second package to version and publish.

## 2026-10-03: The blocks package is ReScript

Its nodes are a variant, so the writer and the renderers switch over every
kind, and `@epure/editor`, which is ReScript, can take the node type as it
is.

Refused: plain JavaScript, which would have copied SWISSID's files faster
and left the nodes untyped.

Costs: about 700 lines ported, held to SWISSID's output by the coordinate
scenarios.

## 2026-10-03: A line scanner splits a document into markdown and blocks

The strict check every site already ran now keeps what it finds: markdown
runs, and blocks with their body as source and their line in the page.

Refused: `markdown-it-container`, whose tokens mix the blocks into
markdown's own stream, so a block's body has to be rebuilt from tokens.

Costs: each markdown run renders on its own. Link references are shared
through one environment; footnotes are not.

## 2026-10-03: The blocks render prose with markdown-it

Refused: marked, which minidoc's own `md` transform uses. markdown-it
parses nested lists strictly, which `flow` relies on, escapes raw HTML, and
is what every site already uses with its plugins.

Costs: a site renders its block pages with markdown-it and any page left on
minidoc's `md` with marked.

## 2026-10-03: A block is read into nodes before it is rendered

The nodes are what a block means, with its prose kept as markdown. They
have a text form, and a scenario's `after` is that text.

Refused: HTML in the reader's scenarios, which pins the markup instead of
the meaning, and markdown straight to HTML, which a live editor cannot
redraw one block at a time.

Costs: the HTML is held by a fixture of its own, one scenario for each kind
of node.

## 2026-10-03: The nodes of a drawing are its coordinates

A `sequence` or a `states` block reads into its placed boxes, lines and
labels. The SVG is painted from them.

Refused: SVG in the scenarios, which is a wall of numbers that any change
of markup rewrites.

Costs: a layout bug that keeps the coordinates, such as two boxes drawn
over each other, shows only on the Blocks page.

## 2026-10-03: `sequence` and `states` are SWISSID's copies, taken whole

Of the two copies, radif's and SWISSID's, SWISSID's is the more mature: it
fixes a stray comma in radif's `sequence` SVG.

Refused: merging the two copies.

## 2026-10-03: A theme sets variables, and never names --tone

A theme is a list of variables under `[data-blocks-theme]`. A block's
colour is `--tone`, set on the block, and the theme gives the amounts that
mix its fill, edge and label from it. A `var()` resolves where it is
declared, so a theme that named `--tone` would resolve it on the theme's
element, where it does not exist.

Refused: themes as rules, which would have to repeat every selector.

Costs: a look a variable does not describe needs a new variable.

## 2026-10-03: A project's kind carries its colour in a style attribute

A kind of party, a kind of box, a kind of move or a screen's owner is a
name the project chooses. Its element carries
`style="--tone: var(--tone-<kind>, var(--blocks-ink))"`, and the site sets
`--tone-<kind>`.

Refused: a CSS rule for each kind, which shared CSS cannot hold for names
it does not know.

Costs: an inline style in the HTML contract.

## 2026-10-03: A move's kind sits in the braces of its label

`review -> rejected  refuse {0.4 fail}`: a position, `right`, and a kind,
all in one place.

Refused: marking the arrow, `review -fail-> rejected`, which would be a
second place where a move takes options.

Costs: one kind name cannot mean one thing for a box and another for a
move.

## 2026-10-07: `states` and `model` place their boxes on one grid

`Grid.res` holds the placing and the lines: the grid of cells, the sides a
line leaves and reaches, the spreading of lines along a side, the curve,
the label and the frame. A box brings its own size, so a table as tall as
its columns sits on the same grid as a state. `states` kept every number of
its fixture through the move.

Refused: `model` as a copy of `states` with tables in its boxes. Two copies
of the routing would drift, and a fix to one would miss the other.

Costs: the entry "`sequence` and `states` are SWISSID's copies, taken whole"
no longer holds for `states`. A fix taken from SWISSID now lands in `Grid`.

## 2026-10-07: An end of a relation is written as it is drawn

`Project ||--o< Site` reads from each table toward the line, so the marks
on the page are the marks in the source. Mermaid's `}` and `{` read too, as
the crow's foot, so a schema copied from mermaid draws unchanged.

Refused: words for the ends (`one-to-many`). A relation would no longer fit
on one line beside its tables.

Zero or one puts the bar at the table and the ring toward the line, as
crow's foot notation does, and as zero or many puts its ring.

## 2026-10-07: The full-screen viewer belongs to the blocks, not to minidoc

`viewer.js` ships with `@epure/minidoc-blocks`. It knows which elements are
drawings, `.sequence`, `.states` and `.model`, and that is the blocks' HTML
contract. A site loads it once in its layout, as it loads `blocks.css`.
`data-select` on the script tag names other blocks to open.

Refused: a helper in minidoc core. Minidoc renders templates and knows no
block, so it would have to learn the blocks' class names.

Refused: every block. A callout or a quote is read at the width of the page.
A drawing is the block the page shrinks.

The viewer inserts its own styles first in the head, so one script tag is
the whole install, and a site's stylesheet still overrides them.

Costs: no scenario runs it. The fixtures read markdown into nodes and
nodes into HTML. The viewer was checked in a browser, which no standing
check drives.

## 2026-10-07: A relation leaves its table straight, for seven tenths of its mark

A crow's foot mark is drawn along the line where it meets its table, so the
line runs straight under it before it curves. The straight piece is 0.7 of
the mark's own reach, chosen by eye on the radif schema.

Refused: the curve starting at the table. It bends under the mark, and the
mark stands beside the line. Refused: a piece as long as the mark, and one
of 20, the marker's box. A curve leaves a straight line so gently that both
looked to start too late. 0.6 and 0.75 were tried too.

## 2026-10-07: An end of a relation has four forms, and no bar

Supersedes the seven ends of "An end of a relation is written as it is
drawn". An end answers two questions with one mark each: a ring, it may
count no row; a crow's foot, it may count more than one. A plain end counts
exactly one. So `--`, `o`, `<` and `o<`, mirrored on the left.

Refused: the bars of crow's foot notation. `||` for exactly one reads as
two, and a bar for one forces a third mark, `o|<`, for zero, one or more.

Costs: a reader of standard crow's foot takes a plain end for "not said".
The docs table states it. Mermaid's tokens still read, drawn as the four.

## 2026-10-08: A table names its tenant with a hash suffix

A table's name line may end with ` #tenant`, one word. The table shows the
tenant, without the hash, at the right of its name, and its group carries
`model__table--tenant-<n>`, where `<n>` counts the tenants in the order they
first appear. `blocks.css` gives the first four a tone each.

Refused: grouping the tables of one tenant, as a radif page would group rows
under their Domain. In a place drawing, a row under another is a parent edge,
so the grouping would draw edges that do not exist.

Costs: one more suffix in the row grammar. A fifth tenant gets the tag and
no tone of its own.

## 2026-10-11: A hidden page lets go of its reload stream

The script `dev` injects closes the stream when the page is hidden and opens
one anew when it is shown.

Refused: one stream per page for the page's life. A browser allows a host six
connections, so tabs left open starved the next page, and an open stream kept
a page out of the back and forward cache.

## 2026-10-11: A failed build reloads nothing

When a build fails, `dev` leaves every open page as it is and sends it the
failure, which the page shows at its foot. A page opened while the build is
broken is told the same. Only a build that lands reloads.

Refused: reloading after every build, which 0.2.0 did. A broken edit then
reloaded the author's page into whatever the failed build left behind.

## 2026-10-11: A build script never empties the output folder

The docs site's build script, and radif's, wrote `rm -rf dist` before `run`.
They no longer do: a run writes each output over the old one, as decided
above, and `dev` serves that folder while the script runs.

Refused: `dev` guarding the folder. It cannot see what a script does, so the
rule is written in the README and the guide instead.

Costs: an output no longer declared stays until someone removes it. A deploy
builds from a fresh checkout and never sees one.

## 2026-10-12: A callout names its author and date as a quote does

`::: rejected "Ada Lovelace" 1843` names who made the call and when. Quotes
and callouts read their info with the same rule, and a callout shows it under
its body, in `callout__by`, as a quote shows it in its `figcaption`.

Refused: the author and date beside the label. The label says what the lines
are, and a byline there would crowd it on a narrow page.

Costs: text after a callout's name was ignored and is now its date.

## 2026-10-19: A model draws a subclass as `Parent <- Child`

The `model` block joins two tables in a second way: a parent and its
subclass. The line is written as the arrow reads, `Parent <- Child`, and
drawn as a class diagram draws it, from the child to its parent with a
hollow triangle at the parent.

Refused: a fifth end token on a relation. An end counts rows, and a parent
counts none.

Costs: a schema that had a table called `<-` cannot be written, which no
table should be.

## 2026-10-19: A secondary line in a drawing is `--drawing-line-secondary`

A line that matters less than the drawing's main lines, such as a model's
subclass link and its arrowhead, takes `--drawing-line-secondary`. Every
theme sets it: a lighter grey than the stroke in soft, and a grey in
graphic.

Refused: `--blocks-line`, which is black in graphic, so a subclass link
would look the same as a relation there.

Costs: one more variable in every theme.

## 2026-10-26: A block is named with a hash suffix, and filed with `annexe`

A quote's or callout's line may end with ` #name`, its anchor in the page,
then ` annexe`, which draws it whole in the page's `::: annexe` and leaves
its title in its place as a link. `` `(name)` `` in the prose is the same
link. A name needs a title in double quotes, for the link to show. The
reader checks the whole page, so a duplicate name, a missing annexe or an
unknown reference stops the build with its line.

Refused: `{{annexe}}`, a variable for the layout. A transform runs after
minidoc resolves variables and returns one string, so it cannot give the
layout a variable. Refused too: a bare `(name)` in the prose, which a typo
would leave as plain text without a word, and a link from the annexe back to
the text, which could return to only one of the places that cite a block.

Costs: inline code that is exactly a word in parentheses is a reference,
and fails when the page has no block of that name. A date that ends in
`annexe` or in `#word` is read as the filing or the name.

## 2026-10-26: A block's title links to its source with `<url>`

A quote's or callout's line may give, after its date, the official source of
its title in angle brackets: `::: quote "Art. 10 al. 2 CPP" RS 312.0
<https://www.fedlex.admin.ch/…> #cpp-10 annexe`. The tail reads `<url>`, then
` #name`, then ` annexe`, each optional, and the date is what is left. The
title under the block becomes a link to the source, in its `cite`. A source
needs a title in double quotes, as a name does.

Refused: pointing `(name)` references and the annexe's link at the source.
They lead to the block in the page, which shows its source in turn.

Costs: a date that ends in `<word>` is read as the source.

## 2026-11-04: The packages live in the `@minidoc` scope

`@epure/minidoc` becomes `@minidoc/core`, in `packages/core`, and
`@epure/minidoc-blocks` becomes `@minidoc/blocks`. The product, its site,
minidoc.dev, and its npm scope now share one name. `core` because the
package is a library, `run`, `dev` and `watch`, that blocks plug into.

Refused: staying in `@epure`, beside `@epure/vitest` and `@epure/editor`,
which names the method rather than the product. Refused too: the bare
`minidoc`, which is another author's package, and `gen`, `site` or `doc`,
which say less than the package does or name the docs site.

Costs: `@epure/minidoc` 0.1.1 stays on npm and is deprecated, and every
site that imports it renames its dependency.

## 2026-11-05: A plain `Error` is a content error, any other kind a bug

`dev` and `watch` print a plain `Error` as its message, on one line. They
print any other kind, such as a `TypeError`, with its stack. A build script
that `dev` runs gets the same rule through a handler loaded before it, so an
error it does not catch skips Node's source excerpt. An error met while
writing an output starts with the output and its page, because that is what
the author opens to fix it.

Refused: a mark that a transform sets on its errors, which every transform
would have to learn. Refused too: dropping the site after the lead, such as
`in build[3].var.content`, which still says which var of the config failed.

Costs: a transform that throws a plain `Error` for a bug loses its stack,
and one that throws a `TypeError` for a content error shows one.

## 2026-11-05: `@epure/minidoc` lives on as a re-export

`packages/deprecated` publishes `@epure/minidoc` 0.2.0, which depends on
`@minidoc/core` and re-exports it, and npm marks it deprecated. A site on
the former name keeps building and gets the fixes of `@minidoc/core` 0.2.x,
with a warning at each install. This supersedes the cost named on
2026-11-04: a site renames its dependency when it wants to, not at once.

Refused: deprecating 0.1.1 alone, which leaves the former name behind every
fix. Refused too: a ReScript module, as `vitest-bdd` had. No ReScript
project uses the former name, and a second `Minidoc` module would clash
with core's.

Costs: a third package to publish while it lives.

## 2026-11-06: A stage of a plan carries its state in its mark

`2. [/] **Add a plan block** building`: `[x]` done, `[/]` in progress, `[ ]` not
started, then the title in bold and a message. A done stage with an open
todo stops the build.

Refused: a state taken from the todos. A stage cannot then be waiting with
nothing checked, and a stage with no todos has no state. Refused too: the
message in braces, which hold a kind or a position in `states`.

Costs: a done stage repeats what its checked todos already say.

## 2026-11-06: Done and in progress are `--tone-done` and `--tone-doing`

Every theme sets both. A stage not started draws in
`--drawing-line-secondary` and `--blocks-muted`, and a stage's rule is as
thick as `--quote-rule`.

Refused: reusing `--tone-draft` and `--tone-proposed`. They name callout
kinds, and graphic sets both to black, so done and in progress would look
alike.

Costs: two more variables for a theme to set.

## 2026-11-06: A long plan picks its stage with radio buttons, not a script

A plan of more than four stages draws each stage as a label around a
hidden radio button, and CSS shows the todos of the checked one beside the
list, with `:has()`. A page numbers its long plans, `plan-1`, `plan-2`, so
each one's buttons form their own group. The grid has one row per stage,
counted in `style="--plan-rows: 6"`, and a last row that takes what the
todos need beyond the stages' height.

Refused: a script, which a site would have to load as it loads
`viewer.js`, and `<details>`, which cannot draw its body beside its
summary.

Costs: two long plans rendered on one page by separate calls share
`plan-1`, and a browser without `:has()` shows no todos.

## 2026-11-06: One publish script for the three packages

`bin/publish.sh` at the root publishes core, blocks or `@epure/minidoc`,
named as its first argument, with the guards core's script had. Core keeps
its `v0.2.0` tags, blocks takes `blocks-v0.1.0`, and `@epure/minidoc`,
which only re-exports core, takes none.

Refused: publishing blocks and `@epure/minidoc` by hand, which skips the
clean-tree check and `pnpm check`. Refused too: a script in each package,
three copies of the same guards.

Costs: a publish runs the whole workspace's `pnpm check`, not one package's.

## 2026-11-06: A block is drawn once, as a tree, by a JSX of the blocks' own

Each block's drawing is ReScript JSX against `Draw`, through ReScript's
generic JSX. It makes a plain tree: elements, text, the HTML markdown-it
gives for prose, and fields. `Draw.write` writes the tree as HTML for a
static page, and `@minidoc/live` writes the same tree as React elements.
Each file that draws names `Draw` with `@@jsxConfig` besides
`rescript.json`, because a project that builds the blocks as a dependency
gives them its own JSX.

Refused: React components as the one source, with the static HTML from
React's server render. Every static site would install React. Refused too:
the HTML strings and React components side by side, checked equal, where
every look is changed twice, and a functor over an element module, whose
types are heavier than a tree for no gain.

Costs: an attribute that one block alone uses joins the one props record,
and a file that draws repeats the JSX setting.

## 2026-11-06: A drawing marks the fields a person may edit, keyed by their place

A field holds a value's source text and how it shows. Its key names its
place, counting from 1: `stage 2 todo 1`, `column 1 step 1 detail 1`,
`widget 3 value`, `part 1 scopes 1`. Plans, flows, screens and API calls
mark theirs. `Draw.fields` lists them once each, in the order they are
drawn, and the fields of a block inside a callout, a quote or a flow of
screens are keyed under `block N`. A static page writes a field as its
text.

Refused: drawing an editable copy of each block beside its drawing. The
flows, screens and API calls would be drawn twice. Refused too: keys from
the node's own structure, such as array indexes from 0, which an author
does not see.

Costs: a field drawn in two places, such as a stage's title, is one key,
and a check, such as a todo being done, is not a field yet.

## 2026-11-06: Live prose beside other children is split into its top-level nodes

`@minidoc/live` gives HTML that is an element's only child as its inner
HTML. HTML beside other children is parsed by the browser into its
top-level nodes, and each element keeps its tag and attributes and takes
its own inner HTML. So a block drawn live has the static page's DOM, and
`@minidoc/live` runs the blocks' `html.test.yaml` and compares the DOM.

Refused: a wrapper element around such prose, which breaks
`.callout__body > :first-child` and the contract. Refused too: one inner
HTML for every part with no editable field, which would leave live's
React path untested until fields become inputs.

Costs: live needs a browser's parser, so it does not render on a server.

## 2026-11-06: A live block reads any source, and keeps a refusal as its value

`Live.read` gives `{source, read}`, where `read` holds the nodes or the
reason minidoc refuses them. One rule serves every block: the host's
parse accepts any string through it, and a refused block draws its reason
above its source and keeps its editor and its pane.

Refused: a parse that fails on a refused source. The editor would draw
the block as invalid and drop its pane, so a typo in the pane would close
it. Refused too: a rule for each kind of block, which would leave an atom
under the wrong rule when its first line changes from `plan` to `flow`.

Costs: a refused block passes through a save like any other.

## 2026-11-06: The blocks and live packages carry ReScript namespaces

`@minidoc/blocks` is `MinidocBlocks`, and `@minidoc/live` is
`MinidocLive`. Their compiled files and JS exports keep their names.

Refused: no namespace. A host that builds them as dependencies, as maia
does, already has a `Node` and a `Plan` of its own. Refused too: maia
binding to live's JS, which loses the types.

Costs: a ReScript host writes `MinidocLive.Live` and lists
`@minidoc/blocks` beside `@minidoc/live` to name its options.

## 2026-11-06: An element writes its attributes in one order

The drawing writes attributes in the order `Draw.Elements.props` declares
them. The blocks wrote a label's `text-anchor` before `x` and `y`, and a
box's after, so a label in a sequence, a state machine or a model now
writes it after them. Every other attribute keeps its place.

Refused: an order kept per element. ReScript writes a record's keys in
the order its type declares.

Costs: a site that compares its HTML as text sees the labels change once.

## 2026-11-06: maia opens a block's source in place until fields become inputs

maia draws its notes' blocks with `@minidoc/live`, in its shadow root. A
click still replaces a block with its source above a live preview, as it
did with HTML strings, so the person sees no change.

Refused, for now: the editor's pane under a selected block, the final
shape. It comes with stage 5, when the drawing itself holds inputs.

Costs: maia keeps its own click-to-edit editor until then.

## 2026-11-07: An edit changes only the characters it touches

`Blocks.edit(source, act, options)` is a pure function in
`@minidoc/blocks`. It answers the new source and the field the caret goes
to. A plan, each stage and each todo keep the line they start on. An edit
reads that one line again with the reader's own patterns, and replaces
only the mark, the title, the message or the text it names. Removing a
stage renumbers only the numbers of the stages after it. Only a source of
one plan takes an act.

Refused: writing the whole block again from its nodes. Lines nobody
touched would change: numbering style, bullets, `__bold__`, spacing.
Refused too: a character span for each field from the reader, which
markdown-it cannot give without a second scanner, and edits in live, in
React, which a flow's edits could then not be tested without a DOM.

Costs: an edit reads its line again, and a source of several blocks is not
editable in live.

## 2026-11-07: A drawing names how each field is edited, and its acts

A field carries its input: `Typed`, where Enter and Backspace in an empty
text may carry an act, or `Clicked(act)`. A stage's number is the field
`stage N mark`, and a todo's box is `… todo M mark`, drawn as nothing on a
static page. `Act` draws "+ stage" and "+ todo", and a static page writes
it as nothing. The HTML contract does not change for them.

Refused: live finding a plan's boxes and numbers by their classes. live
would then know each block's HTML.

Costs: `Draw` carries an act type and an element that a static page never
writes.

## 2026-11-07: A part drawn only where the person may edit is `Draw.edited`

`Edited({shown})` is drawn by live while the person may edit, and written
as nothing on a static page. `fields` walks into it. A plan draws an empty
message inside it, in the same `plan__message` span as a written one, so
the first letter written does not move the field and lose the caret.

Refused: `write` dropping any element whose content is empty, which would
also drop an empty todo's `<li>`. Refused too: an `Act` with no act, which
blurs what an act is.

Costs: one more kind of element for a host that reads the drawing.

## 2026-11-07: An empty stage or todo reads, and `****` is an empty title

A stage or a todo with no text yet reads, as one just added has. An
emptied title leaves `****`, which reads as an empty title, so the message
after it stays a message. A stage with no text, or a plain title given a
message, gets `**` around its title.

Refused: refusing an empty stage or todo. A stage just added would break
the plan until it has a title.

Costs: `****` can no longer stand for literal asterisks in a title.

## 2026-11-07: Each live plan scopes its radio buttons with `useId`

`Live.Editor` puts a prefix of its own, from React's `useId`, before each
radio button's `name`, so two long plans on one page keep separate groups.
`Live.Drawing` and a static page keep `plan-1`.

Refused: a prefix passed through the blocks' options, which changes the
public API for something only live needs.

Costs: an edited plan's `name` attributes differ from the static page's.

## 2026-11-07: A host may give live its text field, drawn for every text

`Live.Editor ~field` takes the host's one-line editor, with `markdown`,
`onChange`, `onEnter(cut)`, `onBackspaceAtStart`, `onLeave` and a handle
whose `focus` takes `"start"`, `"end"` or an offset in the shown text.
When a host gives one, every text of the plan is that field all the time,
and a click puts the caret where the person clicked. It has no look of its
own: it looks exactly like the static page's text. maia gives
`TiliaEditor.Line`, and minidoc does not depend on the editor. Without a
field, a text shows its drawing, and its markdown in a text area under the
caret. An edited text may come back in the editor's form, `__bold__` as
`**bold**`. A text nobody touched never changes.

Refused: the host's field only under the caret, where a text would change
shape on each click and live would have to find where the person clicked.
Refused too: a look of the field's own, and `contenteditable` in live
itself, whose caret in a shadow root is hard to control.

Costs: a plan opens one editor for each of its texts, and syntax the
editor does not know, such as `~~struck~~`, shows as typed.

## 2026-11-07: Enter splits a todo at the caret

A `Typed` field's Enter is a function of the text before and after the
caret, which makes the act. In a todo it gives `SplitTodo({key, before,
after})`. The todo keeps `before`, and a new todo after it holds `after`,
with the todo's indent, bullet and mark, and the caret at its start. Both
halves of a ticked todo stay ticked. At the end of a todo, the todo stays
as written. The space at the cut goes. Enter in a title or a message does
nothing.

Refused: Enter that only adds an empty todo after, leaving the text after
the caret where it was.

Costs: the field must hand live the two halves, as the host's
`onEnter({before, after})` and the box's selection do.

## 2026-11-07: A done stage that takes an open todo moves back in progress

Enter in a done stage's todo, or "+ todo", turns the stage's `x` into `/`,
as unticking one of its todos does.

Refused: leaving the stage done, which the reader refuses because a done
stage with an open todo stops the build.

Costs: an edit changes a mark the person did not click.

## 2026-11-07: The hit and look check runs in headless Chrome, by hand

`pnpm live:hit` draws the editable plans in jsdom, writes their DOM to a
page with `blocks.css`, the themes and `live.css`, and asks Chrome what
lies at the centre of each field and act. It also compares each text in a
host's field with the same text on the static page: the holder's size,
and each word's font, colour and box, word by word, because the field
keeps typed spaces. An empty text is skipped. It checks that a long plan's
side list is a third of its width. `HIT_FIELD` names a host's field to
check in place of the stand-in.

Refused: Playwright as a dependency, and a check on the CSS text, which
misses a pseudo-element over a button.

Costs: it is outside `pnpm check`, because CI has no Chrome, and is run by
hand at the end of every build that touches live, `blocks.css` or a theme.

## 2026-11-07: maia draws its plan as an ordinary `minidoc` atom

The first plan of maia's notes keeps the atom id `plan`, with the format
`minidoc`, under LiveBlock's one rule. LiveBlock takes `blocks.css`, its
themes and `live.css` from the app's links to minidoc. maia's docs keep
their own copy of the blocks until the packages are published.

Refused: a `plan` format with a rule of its own; stage 3 refused a rule
for each kind of block. Refused too: linking maia's docs to minidoc now,
which would make them follow minidoc's uncommitted tree.

Costs: maia carries two copies of the blocks for a while.

## 2026-11-07: A plan draws each stage as a line, its message under it

A stage draws `plan__line`, its number and its title on one line, then
`plan__message`, small and muted, only when it has a message. No count of
todos shows anywhere. In a long plan, the line ends with the state, drawn
by CSS from `--tone`: a check when done, a round dot in progress, nothing
when not started. The band has no mark, because its coloured rule above
each stage shows the state, and its columns are `--flow-gap` apart. A long
plan's side list is a third of the plan's width, has no coloured rule, and
draws the picked stage on `--blocks-surface` with a bold title. A plan
narrower than 30em stacks its stages, by a container query on the plan.
While editing, an empty message shows as a "message" line only when its
stage is hovered, picked, or has the caret.

Refused: reordering the old markup with CSS alone, which keeps the reading
order number, message, title. Refused too: a mark element of its own,
which would hold no text, and the window's width, because maia's card is
narrow in a wide window.

Costs: `plan__state` and `plan__count` leave the HTML contract, and in a
theme whose surface is its canvas, as graphic's is, the picked stage shows
only by its bold title.

## 2026-11-07: A drawing is edited through its source; the page shows it

The page is the editor. Text, the plan and callouts are edited where they
stand. A drawing is not: a click selects it, and `Live.Pane` holds only its
source, with minidoc's reason above it when minidoc refuses it. The drawing
in the page follows each key, so the pane has no preview and no `frame`.
`Live.Drawing` keeps the last value that read, and draws it while a new
source is refused.

Refused: each host keeping the last good form, which every host would
repeat. Refused too: the editor's line for the source. A source has many
lines, so it is a plain text box until a code editor is chosen.

Costs: a drawing keeps its last good form only while it stays mounted.

## 2026-11-07: minidoc is on ReScript 12.3.1

`rescript` and `@rescript/runtime` are 12.3.1 in every package, as in the
editor and maia. The compiled output did not change.

Refused: staying on 12.3.0. maia builds minidoc's packages with its own
compiler, and each build on one side cleaned the other's compiled files.

## 2026-11-07: A page is edited through its markdown, read as CommonMark groups it

In `dev`, each file a page is made of is one section, drawn by one
`TiliaEditor.View`. `@minidoc/edit` reads the markdown with the blocks'
scanner for `:::` blocks and markdown-it's line maps for the rest. A
paragraph, a `- ` item of a flat list and a `#` to `###` title are the
editor's blocks, however they are wrapped in the file. Every other block
is an atom holding its exact source, drawn by `Live.Drawing` and edited
in the panel through `Live.Pane`; the plan is `Live.Editor` in place.
`{{` is text, escaped outside code spans.

Refused: one block per line, which shows a wrapped paragraph as several.
Refused too: an editor for each block, and a shadow root for each block.

Costs: only paragraphs, flat `- ` lists, `#` to `###` titles and the plan
are edited in place. Tables, numbered lists, quotes, `####` titles, code
and callouts go through the panel.

## 2026-11-07: An unchanged block is written as it was

Writing a section back, a block nobody changed writes its original lines,
and the space between blocks is kept. An edited paragraph is broken again
after the same words, by a longest common subsequence of its words. A new
block gets a blank line before it, except an item after an item.

Refused: writing the whole file in the editor's form, which changed 47
places in the docs on the first save.

Costs: an edited block comes back in the editor's form, `*x*` as `_x_`.

## 2026-11-07: A source minidoc refuses is not written

An atom whose source does not read writes the last source that read, as
the drawing keeps its last form, so the site keeps building.

Refused: writing what the person typed, which stops the build and the
page with it while they type.

Costs: a refused source is lost if the page closes before it reads.

## 2026-11-07: `dev` writes the markdown of the folders `edit` names

`dev({edit: ["content"]})` serves `GET` and `PUT /__minidoc/file?path=`.
A `PUT` carries `{text, base, page}` and is refused with 409, and the file
as it is, when the file is no longer `base`. A path outside those folders,
a missing or non-markdown file, a request without the `x-minidoc-edit`
header or from another origin get 403. The reload stream names its page.
When a build lands and one page's own writes are every change, that page
is told `built` and keeps its caret, and every other page reloads. Any
other change reloads every page. A page writes 300 ms after the last key.

Refused: telling a page's own save apart by a time window, and Vite's dev
server.

Costs: a page names itself on the reload stream, and the route answers
only a request with its header from the dev page's origin.

## 2026-11-07: The docs load the editor only in dev, by value vars

`docs:dev` sets `MINIDOC_EDIT` and bundles `src/edit.mjs` into
`dist/edit.js` with esbuild's watch. The docs' layout writes
`{{editFrom}}{{body}}{{editTo}}` and `{{editScript}}`, value vars whose
transforms write nothing without `MINIDOC_EDIT`, each placed so that the
static build stays byte for byte. The story callout and Prism are shared
by the `md` transform and the editor, in `src/options.mjs`.

Refused: a source attribute in the static HTML, and markers written by
core.

Costs: `dist/edit.js` stays in `dist` after dev. A build from a clean
tree, as CI's, has none.

## 2026-11-07: Each section names its own block ids, until the editor prefixes them

`Page.read ~ids` makes the editor's ids unique on the page (`s1b0`,
`s1a3`), and a section is given no `prefix`. In this version, the editor's
`View` draws a section's blocks without its prefix but looks them up with
it, so a prefix makes it ignore every key. A new entry removes this once
the editor passes its prefix to a section's blocks.

Refused: the prefix, which leaves the model unchanged while the page shows
the typing.

Costs: the page, not the editor, keeps the ids apart.

## 2026-11-07: A drawing in the editor drops its outer margins

A drawing sits in the editor's display line, between two zero-width
spaces, and its margins cannot collapse with the text's around it.
`edit.css` drops its first child's top margin, and its last child's
bottom margin when a `#` to `###` title follows. The line takes no room by
`font-size: 0`; the drawing takes back the section's size from
`--edit-size`, a registered property of `edit.css`, not a theme variable.

Refused: changing the editor's display line for minidoc.

Costs: a drawing after a paragraph sits 4 px higher than on the static
page.

## 2026-11-07: minidoc publishes `@epure/minidoc` and `@epure/blocks`, with subpaths

The generator is `@epure/minidoc`, as 0.1.1 on npm is, in
`packages/minidoc`. `dev`'s editor is its subpath `@epure/minidoc/edit`,
in `src/edit`. The blocks are `@epure/blocks`, and live is its subpath
`@epure/blocks/live`, in `src/live`, under one ReScript namespace,
`EpureBlocks`. The editor, the blocks and React are optional peers, needed
only by the subpaths. `src/edit` is a ReScript source of `"type": "dev"`,
so a project that builds the generator from its ReScript never compiles
it. This supersedes "The packages live in the `@minidoc` scope"
(2026-11-04) and "The blocks and live packages carry ReScript namespaces"
(2026-11-06). `pnpm pub` takes `minidoc` or `blocks`, and nothing is
deprecated, since the re-export was never published.

Refused: four packages, one for each of core, edit, blocks and live, which
a site would have to keep at matching versions. Refused too: the
`@minidoc` scope, beside an `@epure/minidoc` that users already install,
and the editor bundled into `dist`, where a host could not share its React.

Costs: a ReScript project that builds `@epure/blocks` compiles live too,
and needs `@rescript/react`. Each package's `exports` lists `./src/*`,
because ReScript output imports compiled files by path.
