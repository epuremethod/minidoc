import { Given } from "@epure/vitest";
import { expect } from "vitest";
import { stringify } from "yaml";
import { makeMemoryFileSystem, run } from "../src/Minidoc.res.mjs";

/** The entry config `run` starts from in every scenario. */
const entry = "config.yaml";

/**
 * A stand-in for a user transform that reports line numbers — a minimal
 * `::: name` container parser accepting only `note`.
 */
const transform = {
  containers: (text: string) =>
    text
      .split("\n")
      .map((line, i) => {
        if (line === ":::") return "</aside>";
        const open = /^:::\s*(\S+)/.exec(line);
        if (!open) return line;
        if (open[1] !== "note") throw new Error(`Unknown container at line ${i + 1}: ${open[1]}`);
        return "<aside>";
      })
      .join("\n"),
};

/**
 * A scenario is a `source` virtual filesystem and either a `target` of
 * expected outputs, an `error` message the run must reject with, or both.
 * `options` merges extra run options (e.g. `inlineErrors`); its harness-only
 * `containers: true` registers the stand-in transform above.
 */
Given("a filesystem", async (_steps, data) => {
  const { source, target, error, options: { containers, ...options } = {} } = readScenario(data);
  const fs = makeMemoryFileSystem(source);
  const opts = containers ? { fs, glob: entry, transform, ...options } : { fs, glob: entry, ...options };
  if (error === undefined) {
    await run(opts);
  } else {
    await expect(run(opts), "run should fail").rejects.toThrow(error);
  }
  for (const [file, content] of Object.entries(target)) {
    expect(await fs.exists(file), `${file} should exist`).toBe(true);
    expect(await fs.readFile(file), file).toBe(content);
  }
});

type Scenario = {
  source: Record<string, string>;
  target: Record<string, string>;
  error?: string;
  options?: Record<string, unknown>;
};

/** Validate the raw scenario data — a stand-in for a schema parser such as sury. */
function readScenario(data: Record<string, unknown>): Scenario {
  const { source, target, error, options, ...unknown } = data;
  const extra = Object.keys(unknown);
  if (extra.length > 0) {
    throw new Error(
      `Unknown scenario key(s): ${extra.join(", ")} (a scenario takes "source", "target", "error", "options")`,
    );
  }
  if (options !== undefined && !isRecord(options)) {
    throw new Error(`"options" must be a mapping of extra run options`);
  }
  if (!isRecord(source)) {
    throw new Error(`A scenario needs a "source" mapping of file -> content`);
  }
  if (error === undefined && !isRecord(target)) {
    throw new Error(`A scenario needs a "target" mapping of file -> content (or an "error")`);
  }
  if (error !== undefined && typeof error !== "string") {
    throw new Error(`"error" must be a string message`);
  }
  return { source: files(source), target: isRecord(target) ? files(target) : {}, error, options };
}

/** A string is file content verbatim; anything else is serialized back to YAML text. */
function files(data: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [name, value] of Object.entries(data)) {
    out[name] = typeof value === "string" ? value : stringify(value);
  }
  return out;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
