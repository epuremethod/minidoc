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
  /**
   * Render content errors as inline error boxes at their place in the output
   * instead of aborting the build (each is also logged to the console).
   * Output path errors still fail loud. Default: false.
   */
  inlineErrors?: boolean;
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

export type WatchOptions = RunOptions & {
  /**
   * Node script spawned for each rebuild. Without it `run` executes in this
   * process, which cannot see an edited transformer: transforms arrive as
   * closures, and no ESM cache hands back a module a file has changed under.
   */
  build?: string;
  /** Directory watched, recursively. Default: the current working directory. */
  root?: string;
  /** More paths watched alongside `root` — files or folders, inside it or not. */
  watch?: string[];
  /** Path segments never watched. Default: dist, node_modules, lib (and any dot-name). */
  ignore?: string[];
  /** Extensions that trigger a rebuild. Default: content, config, and script files. */
  extensions?: string[];
};

export type DevOptions = WatchOptions & {
  /** Directory served, relative to `root`. Default: "dist". */
  serve?: string;
  /** A fixed port; without one, the port remembered in the entry config. */
  port?: number;
};

export interface Watcher {
  /** Stop watching. */
  stop(): void;
}

export interface Server extends Watcher {
  /** The port the dev server is listening on. */
  port: number;
}

/** Build once, then rebuild on every content, config, or script change. */
export declare function watch(options: WatchOptions): Promise<Watcher>;

/**
 * `watch`, plus a static server over the output with live reload. The port is
 * the one remembered in `var: port:` of the entry config; on first launch — or
 * when that port is taken — a free one is drawn and written back there.
 */
export declare function dev(options: DevOptions): Promise<Server>;
