import type { BuildConfig, Config, DirVar, VarValue } from "../api/config.ts";
import type { FileSystem } from "../api/filesystem.ts";
import type { DataValue, DirContent, FileContent, Scope, Value } from "../api/resolve.ts";
import type { Transforms } from "../api/transform.ts";
import { parseConfig } from "./config.ts";
import { splitFrontmatter } from "./frontmatter.ts";
import { globMatcher, joinPath } from "./paths.ts";
import { resolve, resolveValue } from "./resolve.ts";

/** A content file's one-time parse: frontmatter split off its body. */
type Parsed = { vars: Record<string, DataValue>; body: string };

/**
 * Everything a content load needs: the injected services plus a per-run
 * cache that guarantees each file is read and frontmatter-parsed exactly
 * once, however many vars or build entries reference it.
 */
type Loader = {
  fs: FileSystem;
  transforms: Transforms;
  parsed: Map<string, Promise<Parsed>>;
};

/** Read the config at `configPath` and execute every build entry through `fs`. */
export async function run(fs: FileSystem, configPath: string, transforms: Transforms): Promise<void> {
  const chain = await loadChain(fs, configPath);
  const loader: Loader = { fs, transforms, parsed: new Map() };
  // File paths may contain `{{refs}}` (already anchored to the declaring
  // config at parse time). They resolve against string vars only: frontmatter
  // and file bodies are not known until files load, so they cannot shape a path.
  const pathScopes: Scope[] = chain.map(({ path, config }) => ({
    label: `var (${path})`,
    vars: stringVars(config.var),
  }));
  const globals: Scope[] = [];
  for (const { path, config } of chain) {
    globals.push(...(await loadScopes(loader, config.var, `var (${path})`, pathScopes)));
  }
  const [entry] = chain;
  if (!entry) {
    throw new Error(`Config not found: ${configPath}`); // unreachable: loadChain always returns the entry
  }
  await Promise.all(
    entry.config.build.map((build, index) => executeBuild(loader, build, globals, pathScopes, `build[${index}]`)),
  );
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

async function executeBuild(
  loader: Loader,
  build: BuildConfig,
  globals: readonly Scope[],
  pathScopes: readonly Scope[],
  where: string,
): Promise<void> {
  const label = `${where}.var`;
  const buildPathScopes = [{ label, vars: stringVars(build.var) }, ...pathScopes];
  const scopes = [...(await loadScopes(loader, build.var, label, buildPathScopes)), ...globals];
  if (typeof build.input !== "string" && "copy" in build.input) {
    const source = resolve(build.input.copy, buildPathScopes, `${where} input copy`);
    if (!(await loader.fs.exists(source))) {
      throw new Error(`Copy source not found: ${source} (declared at ${where} input)`);
    }
    const output = resolve(build.output, scopes, `${where} output`);
    await loader.fs.copy(source, output);
    return;
  }
  const input = await loadInput(loader, build.input, `${where} input`, buildPathScopes, scopes);
  const output = resolve(build.output, scopes, `${where} output`);
  const content = resolveValue(input, scopes, `${where} input`);
  await loader.fs.writeFile(output, content);
}

/**
 * Load a build's rendered `input`: a template string passes through; a file/dir mapping
 * loads like the matching var kind. A file input exports its frontmatter as
 * the least local scope — usable in the output path — mirroring file vars;
 * a dir input, like dir vars, keeps frontmatter local to each item.
 */
async function loadInput(
  loader: Loader,
  input: Exclude<BuildConfig["input"], { copy: string }>,
  where: string,
  pathScopes: readonly Scope[],
  scopes: Scope[],
): Promise<Value> {
  if (typeof input === "string") {
    return input;
  }
  if ("dir" in input) {
    return loadDir(loader, input, where, pathScopes);
  }
  const file = resolve(input.file, pathScopes, `${where} file`);
  const content = await loadFile(loader, input.transform, file, where);
  scopes.push(content.frontmatter);
  return content;
}

/**
 * Load one `var` block into scopes: the vars themselves, then — less local, so
 * explicit vars win — the frontmatter variables exported by its file vars.
 * Two files exporting the same frontmatter name is a conflict; fail loud.
 */
async function loadScopes(
  loader: Loader,
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
    if (Array.isArray(value)) {
      loaded[name] = { kind: "list", items: value };
      continue;
    }
    if ("dir" in value) {
      // Dir file frontmatter stays local to each item — 8 chapters would
      // conflict on `title` — so dir vars skip the export step below.
      loaded[name] = await loadDir(loader, value, `${label}.${name}`, pathScopes);
      continue;
    }
    if ("list" in value) {
      loaded[name] = {
        source: value.list,
        each: value.each,
        join: value.join ?? "",
        template: value.template,
        where: `${label}.${name}`,
      };
      continue;
    }
    const file = resolve(value.file, pathScopes, `${label}.${name} file`);
    const content = await loadFile(loader, value.transform, file, `${label}.${name}`);
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

/**
 * Load a dir var: list the folder, filter by glob and `where` frontmatter,
 * read each file. Order is `listFiles`'s name-sorted order. Zero matches
 * fail loud (a missing directory lists as empty).
 */
async function loadDir(
  loader: Loader,
  dirVar: DirVar,
  where: string,
  pathScopes: readonly Scope[],
): Promise<DirContent> {
  const dir = resolve(dirVar.dir, pathScopes, `${where} dir`);
  const glob = dirVar.glob ?? "*.md";
  const names = (await loader.fs.listFiles(dir)).filter(globMatcher(glob));
  if (names.length === 0) {
    throw new Error(`No files matching "${glob}" in ${dir} (declared at ${where})`);
  }
  const items: FileContent[] = [];
  for (const name of names) {
    const content = await loadFile(loader, dirVar.transform, joinPath(dir, name), where);
    if (selects(dirVar.where, content.frontmatter.vars)) {
      items.push(content);
    }
  }
  if (items.length === 0) {
    const filter = Object.entries(dirVar.where ?? {})
      .map(([key, value]) => `${key}: ${value}`)
      .join(", ");
    throw new Error(`No files match where (${filter}) in ${dir} (declared at ${where})`);
  }
  return { items, each: dirVar.each, where: `dir ${dir} (${where})` };
}

function selects(filter: Record<string, string> | undefined, vars: Record<string, Value>): boolean {
  return Object.entries(filter ?? {}).every(([name, value]) => vars[name] === value);
}

/** Read one content file; `explicit` overrides the extension-inferred transform. */
async function loadFile(loader: Loader, explicit: string | undefined, file: string, where: string): Promise<FileContent> {
  let parsed = loader.parsed.get(file);
  if (parsed === undefined) {
    parsed = parseFile(loader.fs, file, where);
    loader.parsed.set(file, parsed);
  }
  const { vars, body } = await parsed;
  const name = explicit ?? inferTransform(file);
  if (name === undefined) {
    throw new Error(
      `${where}: cannot infer a transform for ${file} — set "transform" (available: ${Object.keys(loader.transforms).join(", ")})`,
    );
  }
  const transform = loader.transforms[name];
  if (transform === undefined) {
    throw new Error(`${where}: unknown transform "${name}" (available: ${Object.keys(loader.transforms).join(", ")})`);
  }
  return {
    body,
    transform,
    frontmatter: { label: `frontmatter (${file})`, vars },
    where: `file ${file}`,
  };
}

/** One read + frontmatter split per file; `where` is the declaration that first triggered the load. */
async function parseFile(fs: FileSystem, file: string, where: string): Promise<Parsed> {
  if (!(await fs.exists(file))) {
    throw new Error(`Content file not found: ${file} (declared at ${where})`);
  }
  return splitFrontmatter(await fs.readFile(file), file);
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
