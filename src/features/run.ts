import type { Config, PageConfig } from "../api/config.ts";
import type { FileSystem } from "../api/filesystem.ts";
import type { Scope } from "../api/resolve.ts";
import { parseConfig } from "./config.ts";
import { dirname, joinPath } from "./paths.ts";
import { resolve } from "./resolve.ts";

/** Read the config at `configPath` and write every resolved page through `fs`. */
export async function run(fs: FileSystem, configPath: string): Promise<void> {
  const chain = await loadChain(fs, configPath);
  const globals: Scope[] = chain.map(({ path, config }) => ({
    label: `var (${path})`,
    vars: config.var,
  }));
  const [entry] = chain;
  if (!entry) {
    throw new Error(`Config not found: ${configPath}`); // unreachable: loadChain always returns the entry
  }
  if (entry.config.root) {
    await renderPage(fs, entry.config.root, globals, `config ${configPath}`);
  }
  for (const [key, page] of Object.entries(entry.config.pages)) {
    const scopes: Scope[] = [{ label: `pages.${key}.var`, vars: page.var }, ...globals];
    await renderPage(fs, page, scopes, `page "${key}"`);
  }
}

/**
 * Load the entry config and its `base` chain, entry first (most local scope
 * first). Base paths are relative to the config that declares them.
 */
async function loadChain(fs: FileSystem, entryPath: string): Promise<{ path: string; config: Config }[]> {
  const chain: { path: string; config: Config }[] = [];
  const visited: string[] = [];
  let path = entryPath;
  while (true) {
    if (visited.includes(path)) {
      throw new Error(`Base config cycle: ${[...visited, path].join(" -> ")}`);
    }
    visited.push(path);
    if (!(await fs.exists(path))) {
      const from = chain.at(-1);
      const context = from ? ` (base of ${from.path})` : "";
      throw new Error(`Config not found: ${path}${context}`);
    }
    const config = parseConfig(await fs.readFile(path), path);
    chain.push({ path, config });
    if (config.base === undefined) {
      return chain;
    }
    path = joinPath(dirname(path), config.base);
  }
}

async function renderPage(fs: FileSystem, page: PageConfig, scopes: Scope[], where: string): Promise<void> {
  const output = resolve(page.output, scopes, `${where} output`);
  const content = resolve(page.input, scopes, `${where} input`);
  await fs.writeFile(output, content);
}
