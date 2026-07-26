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
