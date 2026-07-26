/**
 * Pure string helpers for the posix-style paths used inside a FileSystem.
 * v1: no `..` normalization — paths are used as written.
 */
export function dirname(path: string): string {
  const index = path.lastIndexOf("/");
  return index < 0 ? "" : path.slice(0, index);
}

export function joinPath(dir: string, path: string): string {
  if (dir === "" || path.startsWith("/")) {
    return path;
  }
  return `${dir}/${path}`;
}

/** Compile a `*`-only glob (e.g. `*.md`) into a basename predicate. */
export function globMatcher(glob: string): (name: string) => boolean {
  const parts = glob.split("*").map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
  const pattern = new RegExp(`^${parts.join(".*")}$`);
  return (name) => pattern.test(name);
}
