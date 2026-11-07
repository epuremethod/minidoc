import { Given } from "@epure/vitest";
import { expect } from "vitest";
import { blocks, draw, edit, read, write } from "../src/Blocks.res.mjs";
import { fields } from "../src/Draw.res.mjs";

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

/**
 * A fields scenario: the `before` is read and drawn, and the `after` lists
 * the drawing's fields, one `key: value` a line, an empty value as `""`.
 */
Given("a block's fields", (_steps, data) => {
  const { before, after, error, options } = readScenario(data);
  if (error !== undefined) throw new Error(`A fields scenario has no "error": it lists fields`);
  const listed = fields(draw(read(before, options), options))
    .map(([key, value]: [string, string]) => `${key}: ${value === "" ? '""' : value}`)
    .join("\n");
  expect(listed).toBe(trimEnd(after ?? ""));
});

/**
 * An edit scenario: the person's `edits` are applied to the `before`, one
 * after the other. Each hands on a block minidoc reads, and the last gives
 * the `after`.
 */
Given("a plan edited", (_steps, data) => {
  const { edits, ...rest } = data;
  const { before, after, error, options } = readScenario(rest);
  if (error !== undefined) throw new Error(`An edit scenario has no "error": it checks the source`);
  if (!Array.isArray(edits)) throw new Error(`An edit scenario needs "edits", a list of what the person does`);
  let source = before;
  for (const one of edits) {
    source = edit(source, act(one), options).source;
    expect(() => read(source, options), `after ${JSON.stringify(one)}`).not.toThrow();
  }
  expect(source).toBe(trimEnd(after ?? ""));
});

/** What the person does, as a scenario names it, as `Draw.act`. */
export function act(one: unknown): unknown {
  if (one === "add a stage") return "AddStage";
  if (!isRecord(one)) throw new Error(`Unknown edit: ${JSON.stringify(one)}`);
  const [[name, key], ...others] = Object.entries(one);
  if (name === "write") {
    if (others.length !== 1 || others[0][0] !== "text") throw new Error(`"write" takes a "text"`);
    return { TAG: "Write", key, text: String(others[0][1]) };
  }
  if (name === "split") {
    const parts = Object.fromEntries(others);
    if (others.length !== 2 || typeof parts.before !== "string" || typeof parts.after !== "string") {
      throw new Error(`"split" takes a "before" and an "after"`);
    }
    return { TAG: "SplitTodo", key, before: parts.before, after: parts.after };
  }
  if (others.length > 0) throw new Error(`"${name}" takes only a key`);
  const tags: Record<string, string> = {
    tick: "Tick",
    "move along": "MoveAlong",
    "add a todo after": "AddTodoAfter",
    "add a todo in": "AddTodoIn",
    remove: "Remove",
  };
  const tag = tags[name];
  if (tag === undefined) throw new Error(`Unknown edit: ${name}`);
  return { TAG: tag, _0: key };
}

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
