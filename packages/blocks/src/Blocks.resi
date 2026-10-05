// @epure/minidoc-blocks — common `:::` blocks for minidoc sites.
// Public interface; kept parallel to Blocks.res.d.mts.

/** The middle language: what a block means, between its markdown and its HTML. */
type node = Node.t

type kinds = {
  /** Kinds of party or box, by name, with the text their legend shows. */
  kinds?: dict<string>,
}

type dialog = {
  /** Who may present a screen, by the word that names them, with their label. */
  owners?: dict<string>,
}

/** A project's own block: its HTML from the rest of its opening line and its body. */
type extra = {
  name: string,
  /** A code fence named `name` instead of a `::: name` block. */
  fence?: bool,
  render: (string, string) => string,
}

type options = {
  /** Callouts added to the common ones, by name, with their label. */
  callouts?: dict<string>,
  @as("ui-dialog") dialog?: dialog,
  sequence?: kinds,
  states?: kinds,
  extra?: array<extra>,
  /** Called with the markdown-it instance, to add the site's own plugins. */
  markdown?: Markdown.t => unit,
}

/** Read a document into nodes. Fails on an unknown, unclosed or mismatched block. */
let read: (string, options) => array<node>

/** The text form of nodes, as the fixtures write them. */
let write: array<node> => string

/** The HTML of nodes. */
let render: (array<node>, options) => string

/** A minidoc transform: markdown in, HTML out, blocks included. */
let blocks: options => string => string
