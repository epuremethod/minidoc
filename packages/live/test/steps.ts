import { Given } from "@epure/vitest";
import { act, createElement } from "react";
import { createRoot } from "react-dom/client";
import { expect } from "vitest";
import { Drawing, Pane, read } from "../src/Live.res.mjs";

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

/**
 * A scenario of the blocks' HTML contract: the `before` is drawn live, and
 * its DOM must be the DOM of the `after`.
 */
Given("a page", (_steps, data) => {
  const { before, after, error, options } = readScenario(data);
  if (error !== undefined) throw new Error(`A page scenario has no "error": it checks HTML`);
  expectSame(drawn(before, options), after ?? "");
});

/**
 * A block drawn live: the `before` is read and drawn, and its DOM must be
 * the DOM of the `after`. An extra block in the options gives its HTML from
 * `html`, with `{info}` and `{body}` filled in.
 */
Given("a block drawn live", (_steps, data) => {
  const { before, after, error, options } = readScenario(data);
  if (error !== undefined) throw new Error(`A live scenario has no "error": a refusal is drawn`);
  expectSame(drawn(before, options), after ?? "");
});

/**
 * A block's pane: the person replaces the `before` with the `typed`
 * source. The pane hands the typed source on, and shows its preview, the
 * `after`, or the reason minidoc refuses it, the `error`.
 */
Given("a block's pane", (_steps, data) => {
  const { before, after, error, options, typed } = readScenario(data);
  if (typed === undefined) throw new Error(`A pane scenario needs a "typed" string: the new source`);
  const changes: string[] = [];
  const container = mount(
    createElement(Pane.make, { value: read(before, options), options, onChange: (source: string) => changes.push(source) }),
  );
  const field = container.querySelector("textarea");
  if (field === null) throw new Error("The pane shows no text field");
  type(field, typed);
  expect(changes).toEqual([typed]);
  if (error === undefined) {
    const preview = container.querySelector(".pane__preview");
    expect(preview, "the pane should show a preview").not.toBeNull();
    expectSame(preview as Element, after ?? "");
  } else {
    expect(container.querySelector(".pane__preview"), "a refused source has no preview").toBeNull();
    expect(container.querySelector(".pane__reason")?.textContent).toBe(error);
  }
});

type Scenario = {
  before: string;
  after?: string;
  error?: string;
  typed?: string;
  options: Record<string, unknown>;
};

/** The options as the blocks take them: each extra block renders from its `html`. */
function blockOptions(options: Record<string, unknown>): Record<string, unknown> {
  const { extra, ...rest } = options;
  if (extra === undefined) return rest;
  if (!Array.isArray(extra)) throw new Error(`"extra" must be a list`);
  return {
    ...rest,
    extra: extra.map((entry: unknown) => {
      if (!isRecord(entry) || typeof entry.name !== "string" || typeof entry.html !== "string") {
        throw new Error(`An extra block needs a "name" and an "html"`);
      }
      const html = entry.html;
      return {
        name: entry.name,
        fence: entry.fence === true,
        render: (info: string, body: string) => html.replaceAll("{info}", info).replaceAll("{body}", body),
      };
    }),
  };
}

function drawn(source: string, options: Record<string, unknown>): Element {
  return mount(createElement(Drawing.make, { value: read(source, options), options }));
}

function mount(element: ReturnType<typeof createElement>): Element {
  const container = document.createElement("div");
  document.body.append(container);
  const root = createRoot(container);
  act(() => root.render(element));
  return container;
}

/** Type into a controlled field as a person does: React hears the input event. */
function type(field: HTMLTextAreaElement, text: string) {
  const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, "value")?.set;
  act(() => {
    setter?.call(field, text);
    field.dispatchEvent(new Event("input", { bubbles: true }));
  });
}

/**
 * The same DOM: the same nodes, text and attributes, and the same style as
 * the DOM reads it. The order of attributes is not part of the DOM: React
 * sets an input's `checked` before its `name`.
 */
function expectSame(drawn: Element, html: string) {
  const expected = document.createElement("div");
  expected.innerHTML = trimEnd(html);
  expect(normal(drawn).replace(/\n+$/, "")).toBe(normal(expected).replace(/\n+$/, ""));
}

function normal(container: Element): string {
  const copy = container.cloneNode(true) as Element;
  for (const element of copy.querySelectorAll("*")) {
    const attributes = [...element.attributes].map((a) =>
      a.name === "style" ? ["style", (element as HTMLElement).style.cssText] : [a.name, a.value],
    );
    for (const [name] of attributes) element.removeAttribute(name as string);
    for (const [name, value] of attributes.sort(([a], [b]) => (a as string).localeCompare(b as string))) {
      element.setAttribute(name as string, value as string);
    }
  }
  return copy.innerHTML;
}

/** Validate the raw scenario data, so a misspelled key fails instead of being ignored. */
function readScenario(data: Record<string, unknown>): Scenario {
  const { before, after, error, options, typed, ...unknown } = data;
  const extra = Object.keys(unknown);
  if (extra.length > 0) {
    throw new Error(
      `Unknown scenario key(s): ${extra.join(", ")} (a scenario takes "before", "after", "error", "typed", "options")`,
    );
  }
  if (typeof before !== "string") throw new Error(`A scenario needs a "before" string: the markdown`);
  if (after === undefined && error === undefined) throw new Error(`A scenario needs an "after" or an "error"`);
  if (after !== undefined && error !== undefined) throw new Error(`A scenario has an "after" or an "error", not both`);
  if (after !== undefined && typeof after !== "string") throw new Error(`"after" must be a string`);
  if (error !== undefined && typeof error !== "string") throw new Error(`"error" must be a string message`);
  if (typed !== undefined && typeof typed !== "string") throw new Error(`"typed" must be a string`);
  if (options !== undefined && !isRecord(options)) throw new Error(`"options" must be a mapping`);
  return { before, after, error, typed, options: blockOptions(options ?? {}) };
}

function trimEnd(text: string): string {
  return text.replace(/\n+$/, "");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
