import { Given } from "@epure/vitest";
import { act, createElement } from "react";
import { createRoot } from "react-dom/client";
import { expect } from "vitest";
import { Drawing, Editor, Pane, read } from "../src/Live.res.mjs";
import { before as beforeCaret, Field, html, markdownOf, place } from "./field.mjs";

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

/**
 * A block edited live: the `before` is drawn where the person may edit,
 * and the `acts` are what the person does, one after the other. Then the
 * last source handed on is the `after`, and what shows matches the other
 * keys: the text under the caret (`shows`), the drawing of the last text
 * left (`drawn`), the field with the caret (`caret`), the picked stage of
 * each long plan (`picked`), the plan's layout (`layout`), fields as they
 * show (`fields`), how many fields are drawn to edit (`inputs`), how many
 * text areas of live's own are drawn (`boxes`), how many sources were
 * handed on (`handed`), and where the caret is in its text as shown
 * (`offset`).
 */
Given("a block edited live", (_steps, data) => editedLive(data));

/** The same, with the stand-in for a host's text field: each text is drawn in it. */
Given("a block edited live in a host's text field", (_steps, data) => editedLive(data, Field));

function editedLive(data: Record<string, unknown>, field?: unknown) {
  const { acts, shows, drawn: left, caret, picked, layout, fields, inputs, boxes, handed, offset, ...rest } = data;
  const { before, after, options } = readScenario({ after: "", ...rest });
  if (!Array.isArray(acts)) throw new Error(`An editing scenario needs "acts", a list of what the person does`);
  const changes: string[] = [];
  const onChange = (source: string) => changes.push(source);
  const container = document.createElement("div");
  document.body.append(container);
  const root = createRoot(container);
  const show = (source: string) =>
    act(() => root.render(createElement(Editor.make, { value: read(source, options), options, onChange, field })));
  show(before);
  const at = (selector: string): HTMLElement => {
    const found = container.querySelector<HTMLElement>(selector);
    if (found === null) throw new Error(`Nothing drawn at ${selector}`);
    return found;
  };
  /** The element with the focus: the text area, or the host's field. */
  const focused = (): HTMLElement => {
    const active = document.activeElement;
    if (!(active instanceof HTMLElement) || !container.contains(active)) throw new Error("No field has the focus");
    return active;
  };
  const press = (key: string, isComposing = false) =>
    act(() => {
      focused().dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, isComposing }));
    });
  let last = "";
  for (const one of acts) {
    if (one === "leave") act(() => focused().blur());
    else if (!isRecord(one)) throw new Error(`Unknown act: ${JSON.stringify(one)}`);
    else {
      const [[name, value]] = Object.entries(one);
      const key = String(value);
      if (name === "click the box of") click(at(`button[data-field="${key} mark"]`));
      else if (name === "click the number of") click(at(`button[data-field="${key} mark"]`));
      else if (name === "click into") {
        last = key;
        if (field === undefined) act(() => at(`span[data-field="${key}"]`).focus());
        else {
          // As the box does, the host's field takes the caret at its end.
          const line = at(`span[data-field="${key}"] > [contenteditable]`);
          act(() => line.focus());
          place(line, line.textContent?.length ?? 0);
        }
      } else if (name === "write") {
        const target = focused();
        if (target instanceof HTMLTextAreaElement) type(target, key);
        else write(target, key);
      } else if (name === "press") press(key);
      else if (name === "press while composing") press(key, true);
      else if (name === "press at the start") {
        const selection = document.getSelection();
        selection?.removeAllRanges();
        const range = document.createRange();
        range.selectNodeContents(focused());
        range.collapse(true);
        selection?.addRange(range);
        press(key);
      } else if (name === "put the caret after") {
        const target = focused();
        const text = target instanceof HTMLTextAreaElement ? target.value : (target.textContent ?? "");
        const found = text.indexOf(key);
        if (found < 0) throw new Error(`"${key}" is not in ${JSON.stringify(text)}`);
        const at = found + key.length;
        if (target instanceof HTMLTextAreaElement) target.setSelectionRange(at, at);
        else place(target, at);
      } else if (name === "click" && key === "+ stage") click(at(`[data-act=""]`));
      else if (name === "click the + todo of") click(at(`[data-act="${key}"]`));
      else if (name === "click the stage of") {
        const [, block, stage] = /^block (\d+) stage (\d+)$/.exec(key) ?? [];
        const plan = container.querySelectorAll(".plan")[Number(block) - 1];
        click(plan.querySelectorAll<HTMLElement>("label.plan__stage")[Number(stage) - 1]);
      } else if (name === "given from outside") show(key);
      else throw new Error(`Unknown act: ${name}`);
    }
  }
  if (rest.after !== undefined) expect(changes.at(-1)).toBe(trimEnd(after ?? ""));
  if (shows !== undefined) {
    const target = focused();
    expect(target instanceof HTMLTextAreaElement ? target.value : markdownOf(target)).toBe(shows);
  }
  if (left !== undefined) expect(at(`span[data-field="${last}"]`).innerHTML).toBe(left);
  if (caret !== undefined) expect(focused().closest<HTMLElement>("[data-field]")?.dataset.field).toBe(caret);
  if (picked !== undefined) {
    const plans = [...container.querySelectorAll(".plan--long")];
    const pickedIn = (plan: Element) => {
      const labels = [...plan.querySelectorAll("label.plan__stage")];
      return `stage ${labels.findIndex((label) => label.querySelector<HTMLInputElement>("input")?.checked) + 1}`;
    };
    const listed = plans.length === 1 ? pickedIn(plans[0]) : plans.map((plan, i) => `block ${i + 1} ${pickedIn(plan)}`).join(", ");
    expect(listed).toBe(picked);
  }
  if (layout !== undefined) expect(at(".plan").classList.contains(`plan--${layout}`)).toBe(true);
  if (fields !== undefined) {
    const shown = String(fields)
      .split("\n")
      .map((line) => {
        const key = line.slice(0, line.indexOf(": "));
        const element = at(`[data-field="${key}"]`);
        return `${key}: ${element instanceof HTMLButtonElement ? element.value : element.textContent}`;
      });
    expect(shown.join("\n")).toBe(String(fields));
  }
  if (inputs !== undefined) expect(container.querySelectorAll("[data-field], textarea").length).toBe(inputs);
  if (boxes !== undefined) expect(container.querySelectorAll("textarea").length).toBe(boxes);
  if (handed !== undefined) expect(changes.length).toBe(handed);
  if (offset !== undefined) {
    const target = focused();
    expect(target instanceof HTMLTextAreaElement ? target.selectionStart : beforeCaret(target)?.length).toBe(offset);
  }
}

/** Write into a host's field as a person does: its text changes, and it hears the input event. */
function write(field: HTMLElement, markdown: string) {
  act(() => {
    field.innerHTML = html(markdown);
    field.dispatchEvent(new Event("input", { bubbles: true }));
  });
}

function click(element: HTMLElement) {
  act(() => element.click());
}

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
