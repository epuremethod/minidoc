import type { Transform } from "./transform.ts";

/** A loaded file var: frontmatter split off, transform picked from the registry. */
export type FileContent = {
  /** File text without its frontmatter block, `{{refs}}` not yet resolved. */
  body: string;
  /** Applied to the resolved body before splicing it into the referencing text. */
  transform: Transform;
  /** Most local scope when resolving `body`: the file's own frontmatter. */
  frontmatter: Scope;
  /** Locates the body in error messages, e.g. `file docs/intro.md`. */
  where: string;
};

/** A loaded dir var: one FileContent per matched file, rendered through `each`. */
export type DirContent = {
  /** Loaded files in render order (name-sorted, `where`-filtered). */
  items: FileContent[];
  /** Expanded once per item with the item's frontmatter and `body` in scope, `{{refs}}` not yet resolved. */
  each: string;
  /** Locates the collection in error messages, e.g. `dir content/guide (var (config.yaml).chapters)`. */
  where: string;
};

export type Value = string | FileContent | DirContent;

/** One layer of variables, most local first. `label` names it in error messages. */
export type Scope = {
  label: string;
  vars: Record<string, Value>;
};
