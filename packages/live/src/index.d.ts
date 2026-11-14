// @minidoc/live — minidoc's blocks drawn in React.
// Hand-written; kept parallel to Live.res.

import type { ReactElement } from "react";
import type { Node, Options } from "@minidoc/blocks";

/** A block as the person wrote it: its source, and its nodes or why minidoc refuses them. */
export type Value = {
  source: string;
  read: { readonly TAG: "Ok"; readonly _0: Node[] } | { readonly TAG: "Error"; readonly _0: string };
};

/** Read a block's source. Any source reads: a refusal is kept in the value, with its reason. */
export function read(source: string, options: Options): Value;

/** Where a host's text field puts the caret: at its start, its end, or an offset in the text as shown, without markup. */
export type Place = "start" | "end" | number;

/** A text cut at the caret by Enter, without the space at the cut. */
export type Cut = { before: string; after: string };

/** What a host's text field lets live do with it. */
export type Handle = { focus: (at: Place) => void };

/**
 * The props of a host's text field: an editor of one block of a text's
 * markdown. It hands on the whole text after each change, and never hands
 * on a text the person did not change. `onEnter` gives the text cut at the
 * caret, in markdown; with none, the caret is at the end.
 */
export type TextField = {
  markdown: string;
  onChange: (markdown: string) => void;
  onEnter: (cut: Cut | undefined) => void;
  onBackspaceAtStart: () => void;
  onLeave: () => void;
  ref: (handle: Handle | null) => void;
};

/**
 * A value's drawing: its nodes as on a static page. A refused value draws
 * the last value this drawing read well; with none yet, it shows the reason
 * above the source.
 */
export declare const Drawing: {
  make: (props: { value: Value; options: Options }) => ReactElement;
};

/**
 * A block the person edits where it stands: a plan, in this version. Each
 * change hands on the block's new source. Any other block draws as
 * `Drawing` does. A host may give its own `field`, an editor of one block
 * of text.
 */
export declare const Editor: {
  make: (props: {
    value: Value;
    options: Options;
    onChange: (source: string) => void;
    field?: (props: TextField) => ReactElement;
  }) => ReactElement;
};

/** A block's source in a text box, with the reason above it when minidoc refuses it. Each change is handed on. */
export declare const Pane: {
  make: (props: {
    value: Value;
    options: Options;
    onChange: (source: string) => void;
    autoFocus?: boolean;
  }) => ReactElement;
};
