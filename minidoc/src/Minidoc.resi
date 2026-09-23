// minidoc — a small documentation website generator.
// Public interface; kept deliberately parallel to Minidoc.res.d.mts.

/**
 The only door to the outside world. Core logic receives a filesystem by
 dependency injection and never imports `node:fs` / `node:path` directly.
*/
type filesystem = {
  readFile: string => promise<string>,
  writeFile: (string, string) => promise<unit>,
  /** Copy a file or directory without interpreting its content. */
  copy: (string, string) => promise<unit>,
  exists: string => promise<bool>,
  /** Name-sorted plain files matching the pattern; relative patterns return root-relative paths. */
  glob: string => promise<array<string>>,
  /** Basenames of the plain files directly inside the dir, name-sorted; `[]` when it does not exist. */
  listFiles: string => promise<array<string>>,
}

/** Pure text transform applied to a content body after variable resolution. */
type transform = string => string

type runOptions = {
  /** Filesystem glob selecting one or more entry config files. */
  glob: string,
  /** Defaults lazily to the Node filesystem rooted at the current working directory. */
  fs?: filesystem,
  /** Named transforms added to or overriding the built-in `md` and `none`. */
  transform?: dict<transform>,
  /**
   Render content errors as inline error boxes at their place in the output
   instead of aborting the build (each is also logged to the console). Output
   path errors still fail loud. Default: false.
  */
  inlineErrors?: bool,
}

/** Discover and run all matching entry configs concurrently. */
let run: runOptions => promise<unit>

/** In-memory filesystem seeded from a name -> content mapping. Used by tests. */
let makeMemoryFileSystem: option<dict<string>> => filesystem

/**
 Node-backed filesystem rooted at a path string or file:// URL (default: the
 current working directory). Creates parent directories on write.
*/
let nodeFs: option<string> => filesystem

// ---------------------------------------------------------------------------
// Development — watch, rebuild, serve.

type watchOptions = {
  ...runOptions,
  /**
   Node script spawned for each rebuild. Without it `run` executes in this
   process, which cannot see an edited transformer: transforms arrive as
   closures, and no ESM cache hands back a module a file has changed under.
  */
  build?: string,
  /** Directory watched, recursively. Default: the current working directory. */
  root?: string,
  /** More paths watched alongside `root` — files or folders, inside it or not. */
  watch?: array<string>,
  /** Path segments never watched. Default: dist, node_modules, lib (and any dot-name). */
  ignore?: array<string>,
  /** Extensions that trigger a rebuild. Default: content, config, and script files. */
  extensions?: array<string>,
}

type devOptions = {
  ...watchOptions,
  /** Directory served, relative to `root`. Default: "dist". */
  serve?: string,
  /** A fixed port; without one, the port remembered in the entry config. */
  port?: int,
}

type watcher = {stop: unit => unit}
type server = {port: int, stop: unit => unit}

/** Build once, then rebuild on every content, config, or script change. */
let watch: watchOptions => promise<watcher>

/**
 `watch`, plus a static server over the output with live reload. The port is
 the one remembered in `var: port:` of the entry config; on first launch — or
 when that port is taken — a free one is drawn and written back there.
*/
let dev: devOptions => promise<server>
