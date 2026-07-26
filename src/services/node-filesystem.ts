import { access, cp, glob as matchFiles, mkdir, readFile, readdir, stat, writeFile } from "node:fs/promises";
import { dirname, isAbsolute, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { FileSystem } from "../api/filesystem.js";

/** Node-backed FileSystem rooted at `root`. Creates parent directories on write. */
export function nodeFs(root: string | URL = process.cwd()): FileSystem {
  const base = root instanceof URL ? fileURLToPath(root) : resolve(root);
  const absolute = (path: string) => (isAbsolute(path) ? normalize(path) : resolve(base, path));

  return {
    async readFile(path) {
      return readFile(absolute(path), "utf8");
    },
    async writeFile(path, content) {
      const file = absolute(path);
      await mkdir(dirname(file), { recursive: true });
      await writeFile(file, content, "utf8");
    },
    async copy(source, output) {
      const target = absolute(output);
      await mkdir(dirname(target), { recursive: true });
      await cp(absolute(source), target, { recursive: true });
    },
    async exists(path) {
      try {
        await access(absolute(path));
        return true;
      } catch {
        return false;
      }
    },
    async glob(pattern) {
      const files: string[] = [];
      for await (const match of matchFiles(pattern, { cwd: base })) {
        try {
          if ((await stat(absolute(match))).isFile()) {
            files.push(match.replaceAll("\\", "/"));
          }
        } catch {
          // A match may disappear while globbing; omit it.
        }
      }
      return files.sort();
    },
    async listFiles(dir) {
      try {
        const entries = await readdir(absolute(dir), { withFileTypes: true });
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
