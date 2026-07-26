export type PageConfig = {
  var: Record<string, string>;
  output: string;
  input: string;
};

export type Config = {
  var: Record<string, string>;
  base?: string;
  /** `pages.<key>` entries, plus a top-level `output`/`input` shorthand page under `root`. */
  pages: Record<string, PageConfig>;
  root?: PageConfig;
};
