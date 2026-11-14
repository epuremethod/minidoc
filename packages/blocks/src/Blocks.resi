// @minidoc/blocks — common `:::` blocks for minidoc sites.
// Public interface; kept parallel to index.d.ts.

/** The middle language: what a block means, between its markdown and its HTML. */
type node = Node.t

type kinds = {
  /** Kinds of party or box, by name, with the text their legend shows. */
  kinds?: dict<string>,
}

type api = {
  /** The words an API call shows, by key: query, headers, body, response, empty. */
  labels?: dict<string>,
}

type dialog = {
  /** Who may present a screen or a form, by the word that names them, with their label. */
  owners?: dict<string>,
}

/** A project's own block: its HTML from the rest of its opening line and its body. */
type extra = {
  name: string,
  render: (string, string) => string,
}

/** What a transform knows of the page it renders: its lang, and its file, as the site names it. */
type rendered = {lang?: string, file?: string}

type options = {
  /** Callouts added to the common ones, by name, with their label. `fr.settled` is the label of `settled` on a page in `fr`. */
  callouts?: dict<string>,
  /** The page's lang, which picks the labels written with its prefix. */
  lang?: string,
  @as("ui-dialog") dialog?: dialog,
  sequence?: kinds,
  states?: kinds,
  api?: api,
  extra?: array<extra>,
  /** Called with the markdown-it instance, to add the site's own plugins. */
  markdown?: Markdown.t => unit,
  /** The text of a file a block names, such as a changelog's, by its path from the page; none when there is no such file. */
  read?: (string, rendered) => option<string>,
}

/** Read a document into nodes. Fails on an unknown, unclosed or mismatched block, and on a name or a reference the page cannot resolve. */
let read: (string, options) => array<node>

/** The text form of nodes, as the fixtures write them. */
let write: array<node> => string

/** The drawing of nodes: elements, text, prose and the fields a person may edit. */
let draw: (array<node>, options) => Draw.element

/** The HTML of nodes: their drawing, written. */
let render: (array<node>, options) => string

/** A source with an act applied, and the field the caret goes to; `None` leaves the caret where it is. */
type edited = Plan.edited = {source: string, caret: option<string>}

/** Whether a person may edit the nodes where they stand: a source of one plan, in this version. */
let editable: array<node> => bool

/** Apply what the person does to the one block of `source`. Fails when the act names no field of it, or when the result would not read. */
let edit: (string, Draw.act, options) => edited

/** The callouts a site knows, by name with their label in `lang`: the common ones first, then the site's own. Fails on a translation of no callout. */
let callouts: options => array<(string, string)>

/** The callouts a page removes once done, such as `comment`: an editor shows a × that removes the block. Such a callout has no label: its author and its date head it on one line. */
let removable: array<string>

/** The keys of the `:::` blocks minidoc draws, other than callouts, such as `states` and `ui-dialog`: the common ones, then the site's own. */
let keys: options => array<string>


/** A minidoc transform: markdown in, HTML out, blocks included. The page's `lang` picks the labels written with its prefix, and `read` gets the page with its `file`. */
let blocks: options => (string, option<rendered>) => string
