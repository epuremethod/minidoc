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
  };
}
