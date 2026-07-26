import { marked } from "marked";
import type { Transforms } from "../api/transform.ts";

/** Default transform registry: `md` renders markdown to html, `none` passes text through. */
export const defaultTransforms: Transforms = {
  md: (text) => marked.parse(text, { async: false }),
  none: (text) => text,
};
