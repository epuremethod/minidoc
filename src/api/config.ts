/**
 * A var whose content comes from an html/md file. The file may start with a
 * `---` YAML frontmatter block declaring scalar variables.
 */
export type FileVar = {
  /** Anchored at parse time: relative to the config that declares it, before var interpolation. */
  file: string;
  /** Transform registry name; inferred from the file extension when absent. */
  transform?: string;
};

export type VarValue = string | FileVar;

export type PageConfig = {
  var: Record<string, VarValue>;
  output: string;
  input: string;
};

export type Config = {
  var: Record<string, VarValue>;
  base?: string;
  /** `pages.<key>` entries, plus a top-level `output`/`input` shorthand page under `root`. */
  pages: Record<string, PageConfig>;
  root?: PageConfig;
};
