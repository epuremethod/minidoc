import type { FileSystem } from "./api/filesystem.js";
import type { Transforms } from "./api/transform.js";
import { run as runWith } from "./features/run.js";
import { defaultTransforms } from "./services/transforms.js";

export type {
  BuildConfig,
  BuildInput,
  Config,
  CopyInput,
  FileVar,
  ListVar,
  TransformVar,
  VarValue,
} from "./api/config.js";
export type { FileSystem } from "./api/filesystem.js";
export type { FileContent, Scope, Value } from "./api/resolve.js";
export type { Transform, Transforms } from "./api/transform.js";
export { parseConfig } from "./features/config.js";
export { splitFrontmatter } from "./features/frontmatter.js";
export { resolve } from "./features/resolve.js";
export { makeMemoryFileSystem } from "./services/memory-filesystem.js";

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
  const filesystem = fs ?? (await import("./services/node-filesystem.js")).nodeFs();
  const configs = await filesystem.glob(glob);
  if (configs.length === 0) {
    throw new Error(`No config files match "${glob}"`);
  }
  const transforms = { ...defaultTransforms, ...transform };
  await Promise.all(configs.sort().map((config) => runWith(filesystem, config, transforms)));
}
