import { parse } from "yaml";
import type { DataValue } from "../api/resolve.ts";

/** Leading `---` block: `---\n<yaml>\n---\n` (or closing `---` at end of file). */
const FRONTMATTER = /^---\n(?:([\s\S]*?)\n)?---(?:\n|$)/;

/**
 * Split an optional leading YAML frontmatter block off a content file.
 * Values may be scalars, nested mappings, or lists of scalars. `where`
 * locates the file in error messages.
 */
export function splitFrontmatter(text: string, where: string): { vars: Record<string, DataValue>; body: string } {
  if (!text.startsWith("---\n")) {
    return { vars: {}, body: text };
  }
  const match = FRONTMATTER.exec(text);
  if (!match) {
    throw new Error(`${where}: unterminated frontmatter (missing closing "---" line)`);
  }
  const vars = readVars(match[1] === undefined ? undefined : parse(match[1]), `${where}: frontmatter`);
  return { vars, body: text.slice(match[0].length) };
}

function readVars(data: unknown, where: string): Record<string, DataValue> {
  if (data === undefined || data === null) {
    return {};
  }
  if (!mapping(data)) {
    throw new Error(`${where}: must be a mapping of names to values`);
  }
  const vars: Record<string, DataValue> = {};
  for (const [name, value] of Object.entries(data)) {
    vars[name] = readValue(value, `${where}.${name}`);
  }
  return vars;
}

function readValue(value: unknown, where: string): DataValue {
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  if (Array.isArray(value)) {
    return {
      kind: "list",
      items: value.map((item, index) => {
        if (typeof item === "string") {
          return item;
        }
        if (typeof item === "number" || typeof item === "boolean") {
          return String(item);
        }
        throw new Error(`${where}[${index}]: must be a scalar value`);
      }),
    };
  }
  if (mapping(value)) {
    const entries: Record<string, DataValue> = {};
    for (const [name, item] of Object.entries(value)) {
      entries[name] = readValue(item, `${where}.${name}`);
    }
    return { kind: "mapping", entries };
  }
  throw new Error(`${where}: must be a scalar, mapping, or list of scalars`);
}

function mapping(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
