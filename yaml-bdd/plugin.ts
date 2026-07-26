import { readFileSync } from "node:fs";
import { relative } from "node:path";
import { SourceMapGenerator } from "source-map";
import type { Plugin } from "vite";
import { isMap, isScalar, LineCounter, parseDocument, stringify, type Node, type Pair } from "yaml";

/**
 * YAML-BDD: compiles `*.test.yaml` fixtures into Vitest suites.
 *
 * Each fixture file is a map of test-name -> case:
 *
 * ```yaml
 * someTest:
 *   description: it should ...
 *   source:            # virtual filesystem the run starts with
 *     config.yaml: ... # mapping values are serialized back to YAML text
 *   target:            # expected filesystem contents after the run
 *     out.html: ...
 *   error: ...         # optional: the run must reject with this message
 * ```
 *
 * The generated module wraps the cases in `describe.concurrent` and source-maps
 * every `it` and assertion back to the original YAML line.
 *
 * Temporary home: this module is slated for extraction into vitest-bdd. It
 * only depends on the harness runtime passed in `options.runtime` — a module
 * exporting `run(fs, entryPath)` and `makeMemoryFileSystem(seed)` taking a
 * `Record<string, string>` — never on minidoc internals.
 */
export type YamlBddOptions = {
  /** Module specifier exporting `run` and `makeMemoryFileSystem` for generated tests. */
  runtime: string;
  /** File suffix compiled into suites. Default: `.test.yaml`. */
  suffix?: string;
  /** Entry config passed to `run`. Default: `config.yaml`. */
  entry?: string;
  /** Print each generated module. */
  debug?: boolean;
};

export function yamlBdd(options: YamlBddOptions): Plugin {
  const suffix = options.suffix ?? ".test.yaml";
  return {
    name: "yaml-bdd",
    enforce: "pre",
    load(id) {
      const path = id.split("?")[0] ?? id;
      if (!path.endsWith(suffix)) {
        return;
      }
      return compile(path, options);
    },
  };
}

type Position = { line: number; column: number };

function compile(path: string, options: YamlBddOptions) {
  const entry = options.entry ?? "config.yaml";
  const text = readFileSync(path, "utf8");
  const lineCounter = new LineCounter();
  const doc = parseDocument(text, { lineCounter });
  if (doc.errors.length > 0) {
    throw new Error(`${path}: ${doc.errors[0]?.message}`);
  }

  const top: Position = { line: 1, column: 0 };
  const posOf = (node: unknown, fallback: Position): Position => {
    if (typeof node === "object" && node !== null && "range" in node && Array.isArray(node.range)) {
      const { line, col } = lineCounter.linePos(node.range[0] as number);
      return { line, column: col - 1 };
    }
    return fallback;
  };

  const out: string[] = [];
  const map = new SourceMapGenerator({ file: path });
  map.setSourceContent(path, text);
  const push = (code: string, position: Position) => {
    out.push(code);
    map.addMapping({
      source: path,
      original: { line: position.line, column: position.column },
      generated: { line: out.length, column: 0 },
    });
  };

  push(`import { describe, expect, it } from "vitest";`, top);
  push(`import { makeMemoryFileSystem, run } from ${JSON.stringify(options.runtime)};`, top);
  push(`describe.concurrent(${JSON.stringify(relative(process.cwd(), path))}, () => {`, top);

  if (isMap(doc.contents)) {
    for (const item of doc.contents.items as Pair<Node, Node | null>[]) {
      compileCase(item);
    }
  }

  push(`});`, top);
  const code = out.join("\n");
  if (options.debug) {
    console.log(code);
  }
  return { code, map: map.toJSON() };

  function compileCase(item: Pair<Node, Node | null>) {
    const casePos = posOf(item.key, top);
    const name = isScalar(item.key) ? String(item.key.value) : "?";
    const fail = (message: string): never => {
      throw new Error(`${path}:${casePos.line}: case "${name}" ${message}`);
    };
    if (!isMap(item.value)) {
      return fail("must be a mapping");
    }
    const entries = new Map<string, Node | null>();
    for (const pair of item.value.items as Pair<Node, Node | null>[]) {
      if (isScalar(pair.key)) {
        entries.set(String(pair.key.value), pair.value);
      }
    }
    const description = entries.get("description");
    const source = entries.get("source");
    const target = entries.get("target");
    const error = entries.get("error");
    if (!isScalar(description) || typeof description.value !== "string") {
      return fail(`needs a string "description"`);
    }
    if (!isMap(source)) {
      return fail(`needs a "source" mapping of file -> content`);
    }
    if (!error && !isMap(target)) {
      return fail(`needs a "target" mapping of file -> content (or an "error")`);
    }

    push(`  it(${JSON.stringify(description.value)}, async () => {`, posOf(description, casePos));
    push(`    const fs = makeMemoryFileSystem({`, posOf(source, casePos));
    for (const pair of source.items as Pair<Node, Node | null>[]) {
      const filePos = posOf(pair.key, casePos);
      const file = isScalar(pair.key) ? String(pair.key.value) : fail("has an invalid source file name");
      push(`      ${JSON.stringify(file)}: ${JSON.stringify(fileContent(pair.value))},`, filePos);
    }
    push(`    });`, posOf(source, casePos));
    if (error) {
      if (!isScalar(error) || typeof error.value !== "string") {
        return fail(`has a non-string "error"`);
      }
      const errorPos = posOf(error, casePos);
      push(
        `    await expect(run(fs, ${JSON.stringify(entry)}), "run should fail").rejects.toThrow(${JSON.stringify(error.value)});`,
        errorPos,
      );
    } else {
      push(`    await run(fs, ${JSON.stringify(entry)});`, posOf(source, casePos));
    }
    if (isMap(target)) {
      for (const pair of target.items as Pair<Node, Node | null>[]) {
        const filePos = posOf(pair.key, casePos);
        const file = isScalar(pair.key) ? String(pair.key.value) : fail("has an invalid target file name");
        const json = JSON.stringify(file);
        push(`    expect(await fs.exists(${json}), ${JSON.stringify(`${file} should exist`)}).toBe(true);`, filePos);
        push(`    expect(await fs.readFile(${json}), ${json}).toBe(${JSON.stringify(fileContent(pair.value))});`, filePos);
      }
    }
    push(`  });`, casePos);
  }

  /** A mapping value is serialized back to YAML text; a string is stored verbatim. */
  function fileContent(node: Node | null | undefined): string {
    if (isScalar(node) && typeof node.value === "string") {
      return node.value;
    }
    return stringify(node?.toJSON());
  }
}
