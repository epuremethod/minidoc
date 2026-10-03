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
