import type { Config, FileVar, PageConfig, VarValue } from "../api/config.ts";
import type { FileSystem } from "../api/filesystem.ts";
import type { FileContent, Scope, Value } from "../api/resolve.ts";
import type { Transforms } from "../api/transform.ts";
import { parseConfig } from "./config.ts";
import { splitFrontmatter } from "./frontmatter.ts";
import { resolve } from "./resolve.ts";

/** Read the config at `configPath` and write every resolved page through `fs`. */
export async function run(fs: FileSystem, configPath: string, transforms: Transforms): Promise<void> {
  const chain = await loadChain(fs, configPath);
  // File paths may contain `{{refs}}` (already anchored to the declaring
  // config at parse time). They resolve against string vars only: frontmatter
  // and file bodies are not known until files load, so they cannot shape a path.
  const pathScopes: Scope[] = chain.map(({ path, config }) => ({
    label: `var (${path})`,
    vars: stringVars(config.var),
  }));
  const globals: Scope[] = [];
  for (const { path, config } of chain) {
    globals.push(...(await loadScopes(fs, transforms, config.var, `var (${path})`, pathScopes)));
  }
  const [entry] = chain;
  if (!entry) {
    throw new Error(`Config not found: ${configPath}`); // unreachable: loadChain always returns the entry
  }
  if (entry.config.root) {
    await renderPage(fs, transforms, entry.config.root, `${configPath}: var`, globals, pathScopes, `config ${configPath}`);
  }
  for (const [key, page] of Object.entries(entry.config.pages)) {
    await renderPage(fs, transforms, page, `pages.${key}.var`, globals, pathScopes, `page "${key}"`);
  }
}

/**
 * Load the entry config and its `base` chain, entry first (most local scope
 * first). Base paths were anchored to their declaring config at parse time.
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
    path = config.base;
  }
}

async function renderPage(
  fs: FileSystem,
  transforms: Transforms,
  page: PageConfig,
  label: string,
  globals: readonly Scope[],
  pathScopes: readonly Scope[],
  where: string,
): Promise<void> {
  const pagePathScopes = [{ label, vars: stringVars(page.var) }, ...pathScopes];
  const scopes = [...(await loadScopes(fs, transforms, page.var, label, pagePathScopes)), ...globals];
  const output = resolve(page.output, scopes, `${where} output`);
  const content = resolve(page.input, scopes, `${where} input`);
  await fs.writeFile(output, content);
}

/**
 * Load one `var` block into scopes: the vars themselves, then — less local, so
 * explicit vars win — the frontmatter variables exported by its file vars.
 * Two files exporting the same frontmatter name is a conflict; fail loud.
 */
async function loadScopes(
  fs: FileSystem,
  transforms: Transforms,
  vars: Record<string, VarValue>,
  label: string,
  pathScopes: readonly Scope[],
): Promise<Scope[]> {
  const loaded: Record<string, Value> = {};
  const exported: Record<string, Value> = {};
  const exportedBy: Record<string, string> = {};
  for (const [name, value] of Object.entries(vars)) {
    if (typeof value === "string") {
      loaded[name] = value;
      continue;
    }
    const file = resolve(value.file, pathScopes, `${label}.${name} file`);
    const content = await loadFile(fs, transforms, value, file, `${label}.${name}`);
    loaded[name] = content;
    for (const [fmName, fmValue] of Object.entries(content.frontmatter.vars)) {
      const by = exportedBy[fmName];
      if (by !== undefined && by !== file) {
        throw new Error(`Frontmatter conflict in ${label}: "${fmName}" defined by both ${by} and ${file}`);
      }
      exportedBy[fmName] = file;
      exported[fmName] = fmValue;
    }
  }
  const scopes: Scope[] = [{ label, vars: loaded }];
  if (Object.keys(exported).length > 0) {
    scopes.push({ label: `frontmatter (${label})`, vars: exported });
  }
  return scopes;
}

/** Read one content file (`file` is the resolved path of `fileVar.file`). */
async function loadFile(
  fs: FileSystem,
  transforms: Transforms,
  fileVar: FileVar,
  file: string,
  where: string,
): Promise<FileContent> {
  if (!(await fs.exists(file))) {
    throw new Error(`Content file not found: ${file} (declared at ${where})`);
  }
  const { vars, body } = splitFrontmatter(await fs.readFile(file), file);
  const name = fileVar.transform ?? inferTransform(file);
  if (name === undefined) {
    throw new Error(
      `${where}: cannot infer a transform for ${file} — set "transform" (available: ${Object.keys(transforms).join(", ")})`,
    );
  }
  const transform = transforms[name];
  if (transform === undefined) {
    throw new Error(`${where}: unknown transform "${name}" (available: ${Object.keys(transforms).join(", ")})`);
  }
  return {
    body,
    transform,
    frontmatter: { label: `frontmatter (${file})`, vars },
    where: `file ${file}`,
  };
}

function inferTransform(file: string): string | undefined {
  if (file.endsWith(".md") || file.endsWith(".markdown")) {
    return "md";
  }
  if (file.endsWith(".html") || file.endsWith(".htm")) {
    return "none";
  }
  return undefined;
}

/** Only the plain string vars of a block — the scopes file paths resolve in. */
function stringVars(vars: Record<string, VarValue>): Record<string, Value> {
  const strings: Record<string, Value> = {};
  for (const [name, value] of Object.entries(vars)) {
    if (typeof value === "string") {
      strings[name] = value;
    }
  }
  return strings;
}
