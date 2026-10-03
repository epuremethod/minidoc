// @epure/minidoc-blocks — common `:::` blocks for minidoc sites.
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
  /** Who may present a screen, by the word that names them, with their label. */
  "ui-dialog"?: { owners?: Record<string, string> };
  /** Kinds of party, by name, with the text their legend shows. */
  sequence?: { kinds?: Record<string, string> };
  /** Kinds of box, by name, with the text their legend shows. */
  states?: { kinds?: Record<string, string> };
  extra?: Extra[];
  /** Called with the markdown-it instance, to add the site's own plugins. */
  markdown?: (md: MarkdownIt) => void;
};

/** Read a document into nodes. Fails on an unknown, unclosed or mismatched block. */
export function read(source: string, options: Options): Node[];

/** The text form of nodes, as the fixtures write them. */
export function write(nodes: Node[]): string;

/** The HTML of nodes. */
export function render(nodes: Node[], options: Options): string;

/** A minidoc transform: markdown in, HTML out, blocks included. */
export function blocks(options: Options): (source: string) => string;
