import type { FileSystem } from "./api/filesystem.ts";
import type { Transforms } from "./api/transform.ts";
import { run as runWith } from "./features/run.ts";
import { defaultTransforms } from "./services/transforms.ts";

export type { BuildConfig, BuildInput, Config, CopyInput, FileVar, ListVar, VarValue } from "./api/config.ts";
export type { FileSystem } from "./api/filesystem.ts";
export type { FileContent, Scope, Value } from "./api/resolve.ts";
export type { Transform, Transforms } from "./api/transform.ts";
export { parseConfig } from "./features/config.ts";
export { splitFrontmatter } from "./features/frontmatter.ts";
export { resolve } from "./features/resolve.ts";
export { makeMemoryFileSystem } from "./services/memory-filesystem.ts";

export type RunOptions = {
  /** FileSystem glob selecting one or more entry config files. */
  glob: string;
  /** Defaults lazily to the Node filesystem rooted at the current working directory. */
  fs?: FileSystem;
  /** Named transforms added to or overriding the built-in `md` and `none`. */
  transform?: Transforms;
};

/** Discover and run all matching entry configs concurrently. */
export async function run({ glob, fs, transform = {} }: RunOptions): Promise<void> {
  const filesystem = fs ?? (await import("./services/node-filesystem.ts")).nodeFs();
  const configs = await filesystem.glob(glob);
  if (configs.length === 0) {
    throw new Error(`No config files match "${glob}"`);
  }
  const transforms = { ...defaultTransforms, ...transform };
  await Promise.all(configs.sort().map((config) => runWith(filesystem, config, transforms)));
}
