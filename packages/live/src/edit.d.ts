// @minidoc/live/edit — a page of a minidoc site as its editor, in `dev`.
// Hand-written; kept parallel to edit/Edit.res.

import type { Options } from "@minidoc/blocks";

/**
 * Draw the file at `path` as its editor, in place of `element`'s content.
 * The element's `data-minidoc-lang` is the page's lang, as the build gave
 * it to the blocks. Each change is written to the file through the dev
 * server.
 */
export function mount(element: Element, path: string, options: Options): Promise<void>;
