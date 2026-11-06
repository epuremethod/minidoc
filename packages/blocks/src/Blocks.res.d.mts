// @minidoc/blocks — common `:::` blocks for minidoc sites.
// Hand-written; kept parallel to Blocks.resi.

/** The middle language: what a block means. Read it with `write`. */
export type Node = { readonly TAG: string } | { readonly TAG: "Markdown"; readonly _0: string };

/** A markdown-it instance, as `markdown` receives it. */
export type MarkdownIt = { use(plugin: unknown, ...options: unknown[]): MarkdownIt };

/** A project's own block: its HTML from the rest of its opening line and its body. */
export type Extra = {
  name: string;
  /** A code fence named `name` instead of a `::: name` block. */
  fence?: boolean;
  render: (info: string, body: string) => string;
};

export type Options = {
  /** Callouts added to the common ones, by name, with their label. */
  callouts?: Record<string, string>;
  /** Who may present a screen or a form (`ui-dialog`, `ui-form`), by the word that names them, with their label. */
  "ui-dialog"?: { owners?: Record<string, string> };
  /** Kinds of party, by name, with the text their legend shows. */
  sequence?: { kinds?: Record<string, string> };
  /** Kinds of box, by name, with the text their legend shows. */
  states?: { kinds?: Record<string, string> };
  /** The words an API call shows, by key: query, headers, body, response, empty. */
  api?: { labels?: Record<string, string> };
  extra?: Extra[];
  /** Called with the markdown-it instance, to add the site's own plugins. */
  markdown?: (md: MarkdownIt) => void;
};

/** Read a document into nodes. Fails on an unknown, unclosed or mismatched block, and on a name or a reference the page cannot resolve. */
export function read(source: string, options: Options): Node[];

/** The text form of nodes, as the fixtures write them. */
export function write(nodes: Node[]): string;

/**
 * A drawing: elements, text, the HTML markdown-it gives for prose, and
 * fields, the values a person may edit. `Nothing` is drawn as nothing.
 */
export type Drawing =
  | { readonly TAG: "Element"; readonly tag: string; readonly attributes: Record<string, string | boolean>; readonly children: Drawing[] }
  | { readonly TAG: "Text"; readonly _0: string }
  | { readonly TAG: "Raw"; readonly _0: string }
  | { readonly TAG: "Field"; readonly key: string; readonly value: string; readonly shown: Drawing }
  | { readonly TAG: "Many"; readonly _0: Drawing[] }
  | "Nothing";

/** The drawing of nodes: elements, text, prose and the fields a person may edit. */
export function draw(nodes: Node[], options: Options): Drawing;

/** The HTML of nodes: their drawing, written. */
export function render(nodes: Node[], options: Options): string;

/** A minidoc transform: markdown in, HTML out, blocks included. */
export function blocks(options: Options): (source: string) => string;
