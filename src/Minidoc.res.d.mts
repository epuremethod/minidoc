/**
 * Hand-written declarations for the ReScript implementation (Minidoc.res).
 * Kept deliberately parallel to Minidoc.resi — same names, same order.
 */

/** Pure text transform applied to a content body after variable resolution. */
export type Transform = (text: string) => string;

/** Named transforms available to file vars, keyed by the name used in `transform:`. */
export type Transforms = Record<string, Transform>;

/**
 * The only door to the outside world. Core logic receives a FileSystem by
 * dependency injection and never imports `node:fs` / `node:path` directly.
 */
export interface FileSystem {
  readFile(path: string): Promise<string>;
  writeFile(path: string, content: string): Promise<void>;
  /** Copy a file or directory without interpreting its content. */
  copy(source: string, output: string): Promise<void>;
  exists(path: string): Promise<boolean>;
  /** Name-sorted plain files matching `pattern`; relative patterns return root-relative paths. */
  glob(pattern: string): Promise<string[]>;
  /** Basenames of the plain files directly inside `dir`, name-sorted; `[]` when the directory does not exist. */
  listFiles(dir: string): Promise<string[]>;
}

export type RunOptions = {
  /** FileSystem glob selecting one or more entry config files. */
  glob: string;
  /** Defaults lazily to the Node filesystem rooted at the current working directory. */
  fs?: FileSystem;
  /** Named transforms added to or overriding the built-in `md` and `none`. */
  transform?: Transforms;
};

/** Discover and run all matching entry configs concurrently. */
export declare function run(options: RunOptions): Promise<void>;

/** In-memory FileSystem seeded from a name -> content mapping. Used by tests. */
export declare function makeMemoryFileSystem(seed?: Record<string, string>): FileSystem;

/**
 * Node-backed FileSystem rooted at a path string or file:// URL (default: the
 * current working directory). Creates parent directories on write.
 */
export declare function nodeFs(root?: string | URL): FileSystem;
