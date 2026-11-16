import { readFileSync } from "node:fs";
import { Given } from "@epure/vitest";
import { parseHTML } from "linkedom";
import { expect } from "vitest";
import "../src2/dom.mjs";
import * as Render from "../src2/Render.mjs";
import * as Sync from "../src2/Sync.mjs";
import * as Parts from "../src2/parts.mjs";
import * as Article from "../src2/Article.mjs";
import * as Page from "@epure/editor/src/domain/feature/Page.mjs";
import * as Storage from "@epure/editor/src/domain/feature/Storage.mjs";
import * as Markdown from "@tilia/editor/src/view/Markdown.mjs";
import * as View from "@tilia/editor/src/view/View.mjs";

/** The default template: level 0 of the croquis. */
const template = readFileSync(new URL("../src2/template.html", import.meta.url), "utf8");

type Shown = {
  images?: { src: string; alt: string }[];
  title?: string;
  nav?: string[];
  article?: string[];
  carries?: Record<string, unknown>;
  head?: string[];
  text?: Record<string, string>;
  contents?: string;
  links?: Record<string, string[]>;
};
type Scenario = { source: Record<string, string>; target?: Record<string, Shown>; error?: string };
type Result<T> = { TAG: "Ok"; _0: T } | { TAG: "Error"; _0: string };

/** The text of each link of the menu, with "(current)" after the current page. */
const nav = (document: Document) =>
  [...document.querySelectorAll("nav a")].map(
    (a) => `${a.textContent}${a.getAttribute("aria-current") === "page" ? " (current)" : ""}`,
  );

/** The text of each block that the editor draws in the article, with no zero-width space. */
const article = (document: Document) =>
  [...document.querySelectorAll("article [id^='block-']")].map((block) => block.textContent?.replace(/\u200b/g, ""));

/** The `src` and the `alt` of each image of the article. */
const images = (document: Document) =>
  [...document.querySelectorAll("article img")].map((img) => ({ src: img.getAttribute("src"), alt: img.getAttribute("alt") }));

/** The href of each stylesheet of the page, in order. */
const head = (document: Document) =>
  [...document.querySelectorAll("link[rel=stylesheet]")].map((link) => link.getAttribute("href"));

/** What the page carries for its hydration. */
const carries = (document: Document) => JSON.parse(document.getElementById("minidoc-data")?.textContent ?? "null");

/**
 * A scenario is a `source` folder, as file names and texts, and either a
 * `target`, what each page shows, or the `error` that refuses the folder.
 * The folder's `index.html` is its template; without one, minidoc's own.
 * Its `components/*.jsx` are built as `dev` builds them for Node.
 */
Given("a folder", (_steps, data) => {
  const { source, target = {}, error } = data as Scenario;
  const result = Render.folder(source, template, false, Parts.fromTexts(source)) as Result<Record<string, string>>;
  if (error !== undefined) {
    expect(result.TAG === "Error" ? result._0 : "no error", "the folder should be refused").toBe(error);
    return;
  }
  if (result.TAG === "Error") throw new Error(result._0);
  const pages = result._0;
  for (const [name, shown] of Object.entries(target)) {
    expect(pages[name], `${name} should be a page`).toBeDefined();
    const { document } = parseHTML(pages[name]);
    if (shown.title !== undefined) expect(document.title, `${name}: title`).toBe(shown.title);
    if (shown.nav !== undefined) expect(nav(document), `${name}: nav`).toEqual(shown.nav);
    if (shown.article !== undefined) expect(article(document), `${name}: article`).toEqual(shown.article);
    if (shown.carries !== undefined) expect(carries(document), `${name}: carries`).toMatchObject(shown.carries);
    if (shown.head !== undefined) expect(head(document), `${name}: head`).toEqual(shown.head);
    if (shown.images !== undefined) expect(images(document), `${name}: images`).toEqual(shown.images);
    if (shown.contents !== undefined)
      expect(document.querySelector('[data-component="contents"]')?.innerHTML, `${name}: contents`).toBe(shown.contents);
    for (const [selector, links] of Object.entries(shown.links ?? {}))
      expect(
        [...document.querySelectorAll(`${selector} a`)].map((a) => `${a.getAttribute("href")} ${a.textContent}`),
        `${name}: links in ${selector}`,
      ).toEqual(links);
    for (const [selector, text] of Object.entries(shown.text ?? {}))
      expect(document.querySelector(selector)?.textContent, `${name}: ${selector}`).toBe(text);
  }
});

type Step =
  | { page: number; opens: string; on?: number }
  | { page: number; saves: string; on: number; text: string }
  | { page: number; stores: string; bytes: string }
  | { page: number; renames: string; as: string }
  | { disk: string; text?: string; bytes?: string; removed?: boolean };
type Exchange = { files: Record<string, string>; steps: Step[]; sent: Record<string, unknown>[] };
type Sent = { to: unknown; message: unknown };

/** A message as the fixture writes it: where it goes, and the pages by their titles. */
const written = ({ to, message }: Sent) => {
  const json = Sync.wire(message) as Record<string, unknown>;
  const pages = json.pages as { title: string }[] | undefined;
  return { to: Sync.where(to), ...json, ...(pages && { pages: pages.map((page) => page.title) }) };
};

/**
 * A scenario is the folder's `files` at the start, the `steps` that change
 * them, and every message `sent`, in order.
 */
Given("a sync", (_steps, data) => {
  const { files, steps, sent } = data as Exchange;
  const sync = Sync.make(files);
  const out: Sent[] = [];
  for (const step of steps) {
    if ("opens" in step) out.push(...Sync.opens(sync, String(step.page), step.opens, step.on ?? 1));
    else if ("saves" in step) out.push(...Sync.saves(sync, String(step.page), step.saves, step.on, step.text));
    else if ("stores" in step) out.push(...Sync.stores(sync, String(step.page), step.stores, step.bytes));
    else if ("renames" in step) out.push(...Sync.renames(sync, String(step.page), step.renames, step.as));
    else out.push(...Sync.changed(sync, step.disk, step.removed ? undefined : (step.text ?? step.bytes)));
  }
  expect(out.map(written)).toEqual(sent.map((message) => ({ ...message, to: String(message.to) })));
});

type Pair = [string, string];
type Landing = { agreed: string; typed?: string; sent?: boolean; lands: string; blocks?: Pair[]; atoms?: Pair[]; writes: string };
type Section = { blocks: Pair[]; atoms: { id: string; value: unknown }[] };

/**
 * A scenario is the `agreed` text, the `typed` text the page holds, and the
 * text that `lands`. The page's engine starts from the agreed text, the
 * person's typing changes its view, and the file lands in it.
 */
Given("a landing", (_steps, data) => {
  const { agreed, typed, sent, lands, blocks, atoms, writes } = data as Landing;
  // The pause is longer than a scenario: what is typed is not given yet.
  const notes = Markdown.make(agreed, () => {}, Article.engineOptions({}), 60000);
  const shown = (): Section => Storage.write(View.doc(notes.state), "page");
  const known = new Set([...shown().blocks.map(([id]) => id), ...shown().atoms.map((atom) => atom.id)]);
  if (typed !== undefined) {
    let next = 0;
    const page = Page.read(typed, Article.kindNames, Article.blocks, undefined, undefined, undefined, shown(), () => `t${++next}`);
    View.act(notes.state, notes.storage, () => Storage.read(page.section));
  }
  // A typed text that was sent: the engine gave it, and the server did not take it.
  if (sent) notes.flush();
  // The page lands a text over the one the server held before it.
  notes.land(lands, agreed);
  // An id the agreed text did not have is `new`, wherever it shows.
  const named = (id: string) => (known.has(id) ? id : "new");
  const section = shown();
  if (blocks !== undefined)
    expect(section.blocks.map(([id, row]) => [named(id), row.replace(/(?<!\\)\{\{([^}]+)\}\}/g, (_, ref) => `{{${named(ref)}}}`)]), "blocks").toEqual(blocks);
  // The atoms in any order: the section keeps the order they were made in.
  const sorted = (pairs: unknown[][]) => pairs.map((pair) => JSON.stringify(pair)).sort();
  if (atoms !== undefined) expect(sorted(section.atoms.map((atom) => [named(atom.id), atom.value])), "atoms").toEqual(sorted(atoms));
  expect(notes.text(), "writes").toBe(writes);
  notes.close();
});
