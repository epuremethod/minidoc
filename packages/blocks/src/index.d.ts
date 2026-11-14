// @minidoc/blocks — common `:::` blocks for minidoc sites.
// Hand-written; kept parallel to Blocks.resi.

/** The middle language: what a block means. Read it with `write`. */
export type Node = { readonly TAG: string } | { readonly TAG: "Markdown"; readonly _0: string };

/** A markdown-it instance, as `markdown` receives it. */
export type MarkdownIt = { use(plugin: unknown, ...options: unknown[]): MarkdownIt };

/** A project's own block: its HTML from the rest of its opening line and its body. */
export type Extra = {
  name: string;
  render: (info: string, body: string) => string;
};

/** What a transform knows of the page it renders: its lang, and its file, as the site names it. */
export type Page = { lang?: string; file?: string };

export type Options = {
  /** Callouts added to the common ones, by name, with their label. `fr.settled` is the label of `settled` on a page in `fr`. */
  callouts?: Record<string, string>;
  /** The page's lang, which picks the labels written with its prefix. */
  lang?: string;
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
  /** The text of a file a block names, such as a changelog's, by its path from the page; undefined when there is no such file. */
  read?: (path: string, page: Page) => string | undefined;
};

/** Read a document into nodes. Fails on an unknown, unclosed or mismatched block, and on a name or a reference the page cannot resolve. */
export function read(source: string, options: Options): Node[];

/** The text form of nodes, as the fixtures write them. */
export function write(nodes: Node[]): string;

/** What the person does to a block. A field is named by its key. */
export type Act =
  | { readonly TAG: "Write"; readonly key: string; readonly text: string }
  | { readonly TAG: "SplitTodo"; readonly key: string; readonly before: string; readonly after: string }
  | { readonly TAG: "Tick" | "MoveAlong" | "AddTodoAfter" | "AddTodoIn" | "Remove"; readonly _0: string }
  | "AddStage";

/**
 * How the person edits a field: as text, where Enter may carry an act made
 * from the text before the caret and the text after it, and Backspace in an
 * empty text may carry an act; or with a click.
 */
export type Input =
  | { readonly TAG: "Typed"; readonly enter?: (before: string, after: string) => Act; readonly erase?: Act }
  | { readonly TAG: "Clicked"; readonly _0: Act };

/**
 * A drawing: elements, text, the HTML markdown-it gives for prose, fields,
 * the values a person may edit, and acts and edited parts, drawn only where
 * the person may edit. `Nothing` is drawn as nothing.
 */
export type Drawing =
  | { readonly TAG: "Element"; readonly tag: string; readonly attributes: Record<string, string | boolean>; readonly children: Drawing[] }
  | { readonly TAG: "Text"; readonly _0: string }
  | { readonly TAG: "Raw"; readonly _0: string }
  | { readonly TAG: "Field"; readonly key: string; readonly value: string; readonly shown: Drawing; readonly input: Input }
  | { readonly TAG: "Act"; readonly act: Act; readonly shown: Drawing }
  | { readonly TAG: "Edited"; readonly shown: Drawing }
  | { readonly TAG: "Many"; readonly _0: Drawing[] }
  | "Nothing";

/** The drawing of nodes: elements, text, prose and the fields a person may edit. */
export function draw(nodes: Node[], options: Options): Drawing;

/** The HTML of nodes: their drawing, written. */
export function render(nodes: Node[], options: Options): string;

/** A source with an act applied, and the field the caret goes to; none leaves the caret where it is. */
export type Edited = { source: string; caret?: string };

/** Whether a person may edit the nodes where they stand: a source of one plan, in this version. */
export function editable(nodes: Node[]): boolean;

/** The callouts a site knows, by name with their label in `lang`: the common ones first, then the site's own. */
export function callouts(options: Options): [string, string][];

/** The keys of the `:::` blocks minidoc draws, other than callouts. */
export function keys(options: Options): string[];

/** The callouts a page removes once done, such as `comment`. */
export const removable: string[];

/** Apply what the person does to the one block of `source`. Fails when the act names no field of it, or when the result would not read. */
export function edit(source: string, act: Act, options: Options): Edited;

/** A minidoc transform: markdown in, HTML out, blocks included. The page's `lang` picks the labels written with its prefix, and `read` gets the page with its `file`. */
export function blocks(options: Options): (source: string, page?: Page) => string;
