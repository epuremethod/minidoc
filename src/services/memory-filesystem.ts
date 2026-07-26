import { globMatcher } from "../features/paths.js";

/** In-memory FileSystem backed by a Map. Used by tests. */
export function makeMemoryFileSystem(seed: Record<string, string> = {}) {
  const files = new Map(Object.entries(seed));
  return {
    files,
    async readFile(path: string) {
      const content = files.get(path);
      if (content === undefined) {
        throw new Error(`File not found: ${path}`);
      }
      return content;
    },
    async writeFile(path: string, content: string) {
      files.set(path, content);
    },
    async copy(source: string, output: string) {
      const content = files.get(source);
      if (content !== undefined) {
        files.set(output, content);
        return;
      }
      const prefix = `${source}/`;
      const matches = [...files.entries()].filter(([path]) => path.startsWith(prefix));
      if (matches.length === 0) {
        throw new Error(`File not found: ${source}`);
      }
      for (const [path, value] of matches) {
        files.set(`${output}/${path.slice(prefix.length)}`, value);
      }
    },
    async exists(path: string) {
      const prefix = `${path}/`;
      return files.has(path) || [...files.keys()].some((file) => file.startsWith(prefix));
    },
    async glob(pattern: string) {
      const matches = globMatcher(pattern);
      return [...files.keys()].filter(matches).sort();
    },
    async listFiles(dir: string) {
      const prefix = dir === "" ? "" : `${dir}/`;
      return [...files.keys()]
        .filter((path) => path.startsWith(prefix) && !path.slice(prefix.length).includes("/"))
        .map((path) => path.slice(prefix.length))
        .sort();
    },
  };
}
