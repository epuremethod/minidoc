import type { FileSystem } from "./api/filesystem.ts";
import type { Transforms } from "./api/transform.ts";
import { run as runWith } from "./features/run.ts";
import { makeTransforms } from "./services/transforms.ts";

export type { Config, FileVar, PageConfig, VarValue } from "./api/config.ts";
export type { FileSystem } from "./api/filesystem.ts";
export type { FileContent, Scope, Value } from "./api/resolve.ts";
export type { Transform, Transforms } from "./api/transform.ts";
export { parseConfig } from "./features/config.ts";
export { splitFrontmatter } from "./features/frontmatter.ts";
export { resolve } from "./features/resolve.ts";
export { makeMemoryFileSystem } from "./services/memory-filesystem.ts";
export { makeTransforms } from "./services/transforms.ts";

/** `features/run` with the default transform registry pre-wired. */
export function run(fs: FileSystem, configPath: string, transforms: Transforms = makeTransforms()): Promise<void> {
  return runWith(fs, configPath, transforms);
}
