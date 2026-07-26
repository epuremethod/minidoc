/**
 * The only door to the outside world. Core logic receives a FileSystem by
 * dependency injection and never imports `node:fs` / `node:path` directly.
 */
export interface FileSystem {
  readFile(path: string): Promise<string>;
  writeFile(path: string, content: string): Promise<void>;
  exists(path: string): Promise<boolean>;
  /** Basenames of the plain files directly inside `dir`, name-sorted; `[]` when the directory does not exist. */
  listFiles(dir: string): Promise<string[]>;
}
