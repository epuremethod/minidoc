import { Given } from "@epure/vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect } from "vitest";
import { blocks, draw, edit, read, write } from "../src/Blocks.mjs";
import { fields } from "../src/Draw.mjs";
import { read as tokens } from "../src/Tokens.mjs";

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
  const { before, after, error, options, page } = readScenario(data);
  if (error !== undefined) throw new Error(`A page scenario has no "error": it checks HTML`);
  expect(trimEnd(blocks(options)(before, page))).toBe(trimEnd(after ?? ""));
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
  page?: Record<string, unknown>;
};

/** Validate the raw scenario data, so a misspelled key fails instead of being ignored. */
function readScenario(data: Record<string, unknown>): Scenario {
  const { before, after, error, options, page, files, ...unknown } = data;
  const extra = Object.keys(unknown);
  if (extra.length > 0) {
    throw new Error(
      `Unknown scenario key(s): ${extra.join(", ")} (a scenario takes "before", "after", "error", "options", "page", "files")`,
    );
  }
  if (typeof before !== "string") throw new Error(`A scenario needs a "before" string: the markdown`);
  if (after === undefined && error === undefined) throw new Error(`A scenario needs an "after" or an "error"`);
  if (after !== undefined && error !== undefined) throw new Error(`A scenario has an "after" or an "error", not both`);
  if (after !== undefined && typeof after !== "string") throw new Error(`"after" must be a string`);
  if (error !== undefined && typeof error !== "string") throw new Error(`"error" must be a string message`);
  if (options !== undefined && !isRecord(options)) throw new Error(`"options" must be a mapping`);
  if (page !== undefined && !isRecord(page)) throw new Error(`"page" must be a mapping: the page the transform renders, such as its lang`);
  if (files !== undefined && !isRecord(files)) throw new Error(`"files" must be a mapping: each path a page names, and its text`);
  // The files a block reads, as a site gives them: by the path the page names.
  const read = files === undefined ? {} : { read: (path: string) => (files as Record<string, string>)[path] };
  return { before, after, error, options: { ...read, ...(options ?? {}) }, page };
}

function trimEnd(text: string): string {
  return text.replace(/\n+$/, "");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * A tokens scenario: the `before` is the source a pane holds, and the
 * `after` is its tokens, each written `<kind>text</kind>`, with the text
 * between them plain. A block with no tokens of its own gives `none`.
 */
Given("a block's tokens", (_steps, data) => {
  const { before, after } = readScenario(data);
  const found = tokens(before);
  const written =
    found === undefined
      ? "none"
      : found.map(([kind, text]: [string, string]) => (kind === "" ? text : `<${kind}>${text}</${kind}>`)).join("");
  expect(written).toBe(after);
});

// The stylesheets that read a theme's variables: this package's, and
// @minidoc/live's, next door.
const stylesheets = ["blocks.css", "../live/live.css", "../live/edit.css"];
// What a block sets on its own element, in a style: no theme sets them.
const ownVariables = ["--tone", "--plan-rows"];
const fileText = (path: string) =>
  readFileSync(join(process.cwd(), path), "utf8").replace(/\/\*[\s\S]*?\*\//g, "");
const readsOf = (css: string) => [...css.matchAll(/var\(\s*(--[\w-]+)/g)].map((m) => m[1]);
const setsOf = (css: string) => [...css.matchAll(/(--[\w-]+)\s*:/g)].map((m) => m[1]);
const unique = (names: string[]) => [...new Set(names)];

/**
 * A theme scenario: the `before` is a file of this package or of the docs,
 * and the `after` lists what it misses, `missing: none` when it misses
 * nothing. A theme misses each variable the stylesheets read and do not set
 * themselves. A page misses each variable the soft theme sets and the page
 * does not name.
 */
Given("a theme's variables", (_steps, data) => {
  const { before, after } = readScenario(data);
  const text = fileText(before);
  const missing = before.endsWith(".css")
    ? unique(
        stylesheets.flatMap((sheet) => {
          const css = fileText(sheet);
          const own = [...setsOf(css), ...ownVariables];
          return readsOf(css).filter((name) => !own.includes(name));
        }),
      ).filter((name) => !setsOf(text).includes(name))
    : unique(setsOf(fileText("themes/soft.css"))).filter(
        (name) => !new RegExp(`${name}(?![\\w-])`).test(text),
      );
  expect(`missing: ${missing.length === 0 ? "none" : missing.join(" ")}`).toBe(after);
});

/** A theme's text with each `light-dark(...)` removed, its parentheses balanced. */
const withoutPairs = (css: string) => {
  let out = "";
  let at = 0;
  for (;;) {
    const start = css.indexOf("light-dark(", at);
    if (start < 0) return out + css.slice(at);
    out += css.slice(at, start);
    let depth = 0;
    let i = start + "light-dark".length;
    for (; i < css.length; i++) {
      if (css[i] === "(") depth++;
      else if (css[i] === ")" && --depth === 0) break;
    }
    at = i + 1;
  }
};

/**
 * A scheme scenario: the `before` is a theme, and the `after` lists each
 * variable that holds a colour (a `#` colour, `rgb()`, `hsl()`, or a
 * colour's name) outside a `light-dark()`: `single: none` when there is
 * none.
 */
Given("a theme's colours", (_steps, data) => {
  const { before, after } = readScenario(data);
  const colour = /#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?|oklch|lab)\(|\b(?:white|black)\b/;
  const single = [...fileText(before).matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)]
    .filter(([, , value]) => colour.test(withoutPairs(value)))
    .map(([, name]) => name);
  expect(`single: ${single.length === 0 ? "none" : single.join(" ")}`).toBe(after);
});
