import { parse } from "yaml";
import type { Config, PageConfig } from "../api/config.ts";

/** Parse and validate one config file. `path` locates it in error messages. */
export function parseConfig(text: string, path: string): Config {
  const data = parse(text);
  if (!isRecord(data)) {
    throw new Error(`${path}: config must be a YAML mapping`);
  }
  const config: Config = {
    var: readVars(data["var"], `${path}: var`),
    pages: {},
  };
  if (data["base"] !== undefined) {
    if (typeof data["base"] !== "string") {
      throw new Error(`${path}: base must be a string path`);
    }
    config.base = data["base"];
  }
  if (data["pages"] !== undefined) {
    if (!isRecord(data["pages"])) {
      throw new Error(`${path}: pages must be a mapping of page configs`);
    }
    for (const [key, page] of Object.entries(data["pages"])) {
      config.pages[key] = readPage(page, `${path}: pages.${key}`);
    }
  }
  if (data["output"] !== undefined || data["input"] !== undefined) {
    config.root = readPage({ var: {}, output: data["output"], input: data["input"] }, path);
  }
  return config;
}

function readPage(data: unknown, where: string): PageConfig {
  if (!isRecord(data)) {
    throw new Error(`${where}: page must be a mapping`);
  }
  if (typeof data["output"] !== "string") {
    throw new Error(`${where}: missing or invalid "output" (must be a string)`);
  }
  if (typeof data["input"] !== "string") {
    throw new Error(`${where}: missing or invalid "input" (must be a string)`);
  }
  return {
    var: readVars(data["var"], `${where}.var`),
    output: data["output"],
    input: data["input"],
  };
}

function readVars(data: unknown, where: string): Record<string, string> {
  if (data === undefined || data === null) {
    return {};
  }
  if (!isRecord(data)) {
    throw new Error(`${where}: must be a mapping of names to values`);
  }
  const vars: Record<string, string> = {};
  for (const [name, value] of Object.entries(data)) {
    if (typeof value === "string") {
      vars[name] = value;
    } else if (typeof value === "number" || typeof value === "boolean") {
      vars[name] = String(value);
    } else {
      throw new Error(`${where}.${name}: must be a scalar value`);
    }
  }
  return vars;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
