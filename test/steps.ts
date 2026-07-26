import { expect } from "vitest";
import { stringify } from "yaml";
import { makeMemoryFileSystem, run } from "../src/index.ts";
import { given } from "../yaml-bdd/steps.ts";

/** The entry config `run` starts from in every scenario. */
const entry = "config.yaml";

/**
 * A scenario is a `source` virtual filesystem and either a `target` of
 * expected outputs, an `error` message the run must reject with, or both.
 */
given("a filesystem", async (data) => {
  const { source, target, error } = readScenario(data);
  const fs = makeMemoryFileSystem(source);
  if (error === undefined) {
    await run({ fs, glob: entry });
  } else {
    await expect(run({ fs, glob: entry }), "run should fail").rejects.toThrow(error);
  }
  for (const [file, content] of Object.entries(target)) {
    expect(await fs.exists(file), `${file} should exist`).toBe(true);
    expect(await fs.readFile(file), file).toBe(content);
  }
});

type Scenario = { source: Record<string, string>; target: Record<string, string>; error?: string };

/** Validate the raw scenario data — a stand-in for a schema parser such as sury. */
function readScenario(data: Record<string, unknown>): Scenario {
  const { source, target, error, ...unknown } = data;
  const extra = Object.keys(unknown);
  if (extra.length > 0) {
    throw new Error(`Unknown scenario key(s): ${extra.join(", ")} (a scenario takes "source", "target", "error")`);
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
  return { source: files(source), target: isRecord(target) ? files(target) : {}, error };
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
