import { parse } from "yaml";
import type {
  BuildConfig,
  BuildInput,
  Config,
  CopyInput,
  DirVar,
  FileVar,
  ListVar,
  TransformVar,
  VarValue,
} from "../api/config.js";
import { dirname, joinPath } from "./paths.js";

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
    const input = readContentVar(data, where, dir);
    if ("list" in input || "value" in input) {
      throw new Error(`${where}: list and transform vars are only valid in a "var" block`);
    }
    return input;
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
    const at = `${where}.${name}`;
    if (isRecord(value)) {
      vars[name] = readContentVar(value, at, dir);
    } else if (Array.isArray(value)) {
      vars[name] = readScalarList(value, at);
    } else {
      vars[name] = readScalar(value, at);
    }
  }
  return vars;
}

function readContentVar(
  data: Record<string, unknown>,
  where: string,
  dir: string,
): FileVar | DirVar | ListVar | TransformVar {
  if (data["dir"] !== undefined) {
    return readDirVar(data, where, dir);
  }
  if (data["file"] !== undefined) {
    return readFileVar(data, where, dir);
  }
  if (data["list"] !== undefined) {
    return readListVar(data, where);
  }
  if (data["value"] !== undefined) {
    return readTransformVar(data, where);
  }
  throw new Error(
    `${where}: a mapping var needs "file" (file var), "dir" (dir var), "list" (list var), or "value" (transform var)`,
  );
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
    if (key !== "dir" && key !== "glob" && key !== "each" && key !== "transform") {
      throw new Error(
        `${where}: unknown key "${key}" (a dir var takes "dir", "each", and optional "glob", "transform")`,
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
  if (data["transform"] !== undefined) {
    if (typeof data["transform"] !== "string") {
      throw new Error(`${where}: "transform" must be a string`);
    }
    dirVar.transform = data["transform"];
  }
  return dirVar;
}

function readListVar(data: Record<string, unknown>, where: string): ListVar {
  for (const key of Object.keys(data)) {
    if (key !== "list" && key !== "each" && key !== "join" && key !== "template") {
      throw new Error(
        `${where}: unknown key "${key}" (a list var takes "list", "each", and optional "join", "template")`,
      );
    }
  }
  if (typeof data["list"] !== "string") {
    throw new Error(`${where}: missing or invalid "list" (must be a variable name)`);
  }
  if (typeof data["each"] !== "string") {
    throw new Error(`${where}: missing or invalid "each" (must be a string template)`);
  }
  const listVar: ListVar = { list: data["list"], each: data["each"] };
  if (data["join"] !== undefined) {
    if (typeof data["join"] !== "string") {
      throw new Error(`${where}: "join" must be a string`);
    }
    listVar.join = data["join"];
  }
  if (data["template"] !== undefined) {
    if (typeof data["template"] !== "string") {
      throw new Error(`${where}: "template" must be a string`);
    }
    listVar.template = data["template"];
  }
  return listVar;
}

function readTransformVar(data: Record<string, unknown>, where: string): TransformVar {
  for (const key of Object.keys(data)) {
    if (key !== "value" && key !== "transform") {
      throw new Error(`${where}: unknown key "${key}" (a transform var takes "value" and "transform")`);
    }
  }
  if (typeof data["value"] !== "string") {
    throw new Error(`${where}: missing or invalid "value" (must be a string template)`);
  }
  if (typeof data["transform"] !== "string") {
    throw new Error(`${where}: missing or invalid "transform" (must be a string)`);
  }
  return { value: data["value"], transform: data["transform"] };
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

function readScalarList(value: unknown[], where: string): string[] {
  return value.map((item, index) => readScalar(item, `${where}[${index}]`));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
