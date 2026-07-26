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
    async exists(path: string) {
      return files.has(path);
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
