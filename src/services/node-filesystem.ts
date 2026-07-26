import { access, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import type { FileSystem } from "../api/filesystem.ts";

/** Node-backed FileSystem for real runs. Creates parent directories on write. */
export function makeNodeFileSystem(): FileSystem {
  return {
    async readFile(path) {
      return readFile(path, "utf8");
    },
    async writeFile(path, content) {
      await mkdir(dirname(path), { recursive: true });
      await writeFile(path, content, "utf8");
    },
    async exists(path) {
      try {
        await access(path);
        return true;
      } catch {
        return false;
      }
    },
    async listFiles(dir) {
      try {
        const entries = await readdir(dir, { withFileTypes: true });
        return entries
          .filter((entry) => entry.isFile())
          .map((entry) => entry.name)
          .sort();
      } catch {
        return [];
      }
    },
  };
}
