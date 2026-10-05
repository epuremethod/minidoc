import { Given } from "@epure/vitest";
import { expect } from "vitest";
import { blocks, read, write } from "../src/Blocks.res.mjs";

/**
 * A reader scenario: the `before` is read into nodes, and the nodes are
 * written in their text form. The `after` is that text, or the `error` is
 * the message the reader fails with.
 */
Given("a document", (_steps, data) => {
  const { before, after, error, options } = readScenario(data);
  const nodes = () => write(read(before, options));
  if (error === undefined) {
    expect(trimEnd(nodes())).toBe(trimEnd(after ?? ""));
  } else {
    expect(nodes, "reading should fail").toThrow(error);
  }
});

/**
 * A page scenario: the `before` goes through the transform, and the `after`
 * is the HTML it must give.
 */
Given("a page", (_steps, data) => {
  const { before, after, error, options } = readScenario(data);
  if (error !== undefined) throw new Error(`A page scenario has no "error": it checks HTML`);
  expect(trimEnd(blocks(options)(before))).toBe(trimEnd(after ?? ""));
});

type Scenario = {
  before: string;
  after?: string;
  error?: string;
  options: Record<string, unknown>;
};

/** Validate the raw scenario data, so a misspelled key fails instead of being ignored. */
function readScenario(data: Record<string, unknown>): Scenario {
  const { before, after, error, options, ...unknown } = data;
  const extra = Object.keys(unknown);
  if (extra.length > 0) {
    throw new Error(
      `Unknown scenario key(s): ${extra.join(", ")} (a scenario takes "before", "after", "error", "options")`,
    );
  }
  if (typeof before !== "string") throw new Error(`A scenario needs a "before" string: the markdown`);
  if (after === undefined && error === undefined) throw new Error(`A scenario needs an "after" or an "error"`);
  if (after !== undefined && error !== undefined) throw new Error(`A scenario has an "after" or an "error", not both`);
  if (after !== undefined && typeof after !== "string") throw new Error(`"after" must be a string`);
  if (error !== undefined && typeof error !== "string") throw new Error(`"error" must be a string message`);
  if (options !== undefined && !isRecord(options)) throw new Error(`"options" must be a mapping`);
  return { before, after, error, options: options ?? {} };
}

function trimEnd(text: string): string {
  return text.replace(/\n+$/, "");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
