import { parse } from "yaml";
import type { BuildConfig, BuildInput, Config, CopyInput, DirVar, FileVar, VarValue } from "../api/config.ts";
import { dirname, joinPath } from "./paths.ts";

/**
 * Parse and validate one config file. `path` locates it in error messages.
 *
 * Every declared path (`base`, `output`, `var` file paths) is anchored here,
 * relative to the declaring config's directory, before any var interpolation —
 * so a var can contribute path segments but never move the anchor.
 */
export function parseConfig(text: string, path: string): Config {
  const data = parse(text);
  if (!isRecord(data)) {
    throw new Error(`${path}: config must be a YAML mapping`);
  }
  const dir = dirname(path);
  const config: Config = {
    var: readVars(data["var"], `${path}: var`, dir),
    build: [],
  };
  if (data["base"] !== undefined) {
    if (typeof data["base"] !== "string") {
      throw new Error(`${path}: base must be a string path`);
    }
    config.base = joinPath(dir, data["base"]);
  }
  if (data["build"] !== undefined) {
    if (!Array.isArray(data["build"])) {
      throw new Error(`${path}: build must be a sequence`);
    }
    config.build = data["build"].map((build, index) => readBuild(build, `${path}: build[${index}]`, dir));
  }
  return config;
}

function readBuild(data: unknown, where: string, dir: string): BuildConfig {
  if (!isRecord(data)) {
    throw new Error(`${where}: build entry must be a mapping`);
  }
  if (typeof data["output"] !== "string") {
    throw new Error(`${where}: missing or invalid "output" (must be a string)`);
  }
  if (typeof data["input"] !== "string" && !isRecord(data["input"])) {
    throw new Error(`${where}: missing or invalid "input" (must be a string or a file/dir/copy mapping)`);
  }
  return {
    var: readVars(data["var"], `${where}.var`, dir),
    output: joinPath(dir, data["output"]),
    input: isRecord(data["input"]) ? readInput(data["input"], `${where}.input`, dir) : data["input"],
  };
}

function readInput(data: Record<string, unknown>, where: string, dir: string): BuildInput {
  if (data["copy"] === undefined) {
    return readContentVar(data, where, dir);
  }
  return readCopyInput(data, where, dir);
}

function readCopyInput(data: Record<string, unknown>, where: string, dir: string): CopyInput {
  for (const key of Object.keys(data)) {
    if (key !== "copy") {
      throw new Error(`${where}: unknown key "${key}" (a copy input takes "copy")`);
    }
  }
  if (typeof data["copy"] !== "string") {
    throw new Error(`${where}: missing or invalid "copy" (must be a string path)`);
  }
  return { copy: joinPath(dir, data["copy"]) };
}

function readVars(data: unknown, where: string, dir: string): Record<string, VarValue> {
  if (data === undefined || data === null) {
    return {};
  }
  if (!isRecord(data)) {
    throw new Error(`${where}: must be a mapping of names to values`);
  }
  const vars: Record<string, VarValue> = {};
  for (const [name, value] of Object.entries(data)) {
    vars[name] = isRecord(value) ? readContentVar(value, `${where}.${name}`, dir) : readScalar(value, `${where}.${name}`);
  }
  return vars;
}

function readContentVar(data: Record<string, unknown>, where: string, dir: string): FileVar | DirVar {
  if (data["dir"] !== undefined) {
    return readDirVar(data, where, dir);
  }
  if (data["file"] !== undefined) {
    return readFileVar(data, where, dir);
  }
  throw new Error(`${where}: a mapping var needs "file" (file var) or "dir" (dir var)`);
}

function readFileVar(data: Record<string, unknown>, where: string, dir: string): FileVar {
  for (const key of Object.keys(data)) {
    if (key !== "file" && key !== "transform") {
      throw new Error(`${where}: unknown key "${key}" (a file var takes "file" and an optional "transform")`);
    }
  }
  if (typeof data["file"] !== "string") {
    throw new Error(`${where}: missing or invalid "file" (must be a string path)`);
  }
  const fileVar: FileVar = { file: joinPath(dir, data["file"]) };
  if (data["transform"] !== undefined) {
    if (typeof data["transform"] !== "string") {
      throw new Error(`${where}: "transform" must be a string`);
    }
    fileVar.transform = data["transform"];
  }
  return fileVar;
}

function readDirVar(data: Record<string, unknown>, where: string, dir: string): DirVar {
  for (const key of Object.keys(data)) {
    if (key !== "dir" && key !== "glob" && key !== "where" && key !== "each" && key !== "transform") {
      throw new Error(
        `${where}: unknown key "${key}" (a dir var takes "dir", "each", and optional "glob", "where", "transform")`,
      );
    }
  }
  if (typeof data["dir"] !== "string") {
    throw new Error(`${where}: missing or invalid "dir" (must be a string path)`);
  }
  if (data["each"] !== undefined && typeof data["each"] !== "string") {
    throw new Error(`${where}: "each" must be a string template`);
  }
  const dirVar: DirVar = { dir: joinPath(dir, data["dir"]), each: data["each"] ?? "{{body}}" };
  if (data["glob"] !== undefined) {
    if (typeof data["glob"] !== "string") {
      throw new Error(`${where}: "glob" must be a string`);
    }
    dirVar.glob = data["glob"];
  }
  if (data["where"] !== undefined) {
    dirVar.where = readScalarVars(data["where"], `${where}.where`);
  }
  if (data["transform"] !== undefined) {
    if (typeof data["transform"] !== "string") {
      throw new Error(`${where}: "transform" must be a string`);
    }
    dirVar.transform = data["transform"];
  }
  return dirVar;
}

/** Scalar-only var block, used for content file frontmatter. */
export function readScalarVars(data: unknown, where: string): Record<string, string> {
  if (data === undefined || data === null) {
    return {};
  }
  if (!isRecord(data)) {
    throw new Error(`${where}: must be a mapping of names to values`);
  }
  const vars: Record<string, string> = {};
  for (const [name, value] of Object.entries(data)) {
    vars[name] = readScalar(value, `${where}.${name}`);
  }
  return vars;
}

function readScalar(value: unknown, where: string): string {
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  throw new Error(`${where}: must be a scalar value`);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
