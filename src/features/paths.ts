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

/** Compile a `*`/`**` glob into a path predicate. `*` never crosses `/`; `**` does. */
export function globMatcher(glob: string): (name: string) => boolean {
  let source = "";
  for (let index = 0; index < glob.length; index += 1) {
    const char = glob[index] ?? "";
    if (char !== "*") {
      source += char.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      continue;
    }
    if (glob[index + 1] !== "*") {
      source += "[^/]*";
      continue;
    }
    index += 1;
    if (glob[index + 1] === "/") {
      index += 1;
      source += "(?:.*/)?";
    } else {
      source += ".*";
    }
  }
  const pattern = new RegExp(`^${source}$`);
  return (name) => pattern.test(name.replaceAll("\\", "/"));
}
