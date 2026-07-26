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

/**
 * A var whose content is a folder of html/md files, each rendered through the
 * `each` template and concatenated in filename order.
 */
export type DirVar = {
  /** Anchored at parse time: relative to the config that declares it, before var interpolation. */
  dir: string;
  /** Basename pattern, `*` wildcard only. Defaults to `*.md`. */
  glob?: string;
  /** Keeps only files whose frontmatter matches every entry (string equality). */
  where?: Record<string, string>;
  /** Item template; sees the file's frontmatter and its content as `{{body}}`. Defaults to `{{body}}`. */
  each: string;
  /** Transform registry name for every file; inferred per file when absent. */
  transform?: string;
};

export type VarValue = string | FileVar | DirVar;

export type PageConfig = {
  var: Record<string, VarValue>;
  output: string;
  /** A template string, or directly a file/dir var rendered as the page body. */
  input: string | FileVar | DirVar;
};

export type Config = {
  var: Record<string, VarValue>;
  base?: string;
  /** `pages.<key>` entries, plus a top-level `output`/`input` shorthand page under `root`. */
  pages: Record<string, PageConfig>;
  root?: PageConfig;
};
