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

export type CopyInput = {
  /** Anchored at parse time and copied without reading or transforming its content. */
  copy: string;
};

export type BuildInput = string | FileVar | DirVar | CopyInput;

export type BuildConfig = {
  var: Record<string, VarValue>;
  output: string;
  /** A rendered template/file/dir, or an opaque file/directory copy. */
  input: BuildInput;
};

export type Config = {
  var: Record<string, VarValue>;
  base?: string;
  build: BuildConfig[];
};
