// The hit check: each field a person edits live, and each act, must take
// the click at its centre in a real browser. jsdom has no layout, so a
// drawing's pseudo-element over a button, such as a done todo's check mark,
// passes every scenario and still takes the click. This draws the editable
// blocks in jsdom, writes their DOM to a page with blocks.css, a theme and
// live.css, and asks headless Chrome what lies at the centre of each one.
//
// It also checks the look of a host's text field, with the stand-in in
// field.mjs: each text drawn in the field must have the font, size, colour
// and place of the same text on a static page. An empty text has no text
// on a static page, so it is not compared.
//
// Run it with `pnpm hit` here or `pnpm live:hit` at the root, at the end of
// every build that changes live, blocks.css or a theme. It needs Chrome or
// Chromium: set CHROME to its path when it is not found.

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { JSDOM } from "jsdom";

const dom = new JSDOM("<!doctype html><body></body>", { pretendToBeVisual: true });
for (const name of ["window", "document", "HTMLElement", "Node", "Element", "Event", "KeyboardEvent"]) {
  globalThis[name] = dom.window[name];
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const { act, createElement } = await import("react");
const { createRoot } = await import("react-dom/client");
const { Drawing, Editor, read } = await import("../src/Live.mjs");
// HIT_FIELD names a module whose `Field` is a host's own text field, such
// as the editor's block in maia, to check in place of the stand-in.
const { Field } = await import(process.env.HIT_FIELD ?? "./field.mjs");

const plan = `::: plan Release
1. [x] **Intention** agreed
   - [x] Agree on it
   - [X] Write it down
2. [/] **Build** building
   - [x] Draw it
   - [ ] Test it
   - [ ]
3. [ ] **Ship**
:::`;

const long = `::: plan
1. [x] **One**
   - [x] Done
2. [/] **Two** now
   - [x] Done
   - [ ] Open
   - [ ]
3. [ ] **Three**
4. [ ] **Four**
5. [ ]
:::`;

const todos = `::: plan
- [x] Done
- [ ] Open
- [ ]
:::`;

/** Each case: its source, the field the caret is in, if any, and whether the texts are the host's field. */
const cases = [
  { name: "a short plan", source: plan },
  { name: "a short plan, with the caret in a todo", source: plan, caret: "stage 2 todo 2" },
  { name: "a short plan, with the caret in a message", source: plan, caret: "stage 3 message" },
  { name: "a long plan", source: long },
  { name: "a long plan, with the caret in a stage title", source: long, caret: "stage 2 title" },
  { name: "a long plan, picked on a stage with no message", source: long.replace("**Two** now", "**Two**") },
  { name: "a plan of todos, untitled", source: todos },
  { name: "a short plan, in the host's field", source: plan, field: true },
  { name: "a long plan, in the host's field", source: long, field: true },
];

const marked = `::: plan Release *one*
1. [x] **Intention** \`agreed\`
   - [x] Agree on it
   - [x] Write it in **bold** and *italic*
2. [/] **Build** with [a link](https://minidoc.dev)
   - [ ] Run \`pnpm check\` and **all** of *them*
   - [ ] See [the docs](https://minidoc.dev) for a text long enough to wrap onto a second line of the todo, at the width the page gives it
3. [ ] **Ship** _soon_
   - [ ] Tag it
:::`;

const markedLong = `${marked.slice(0, -4)}
4. [ ] **Four**
   - [ ] Open
5. [ ] **Five** last
   - [ ] Close
:::`;

/** Each look: a plan drawn twice, as on a static page and with each text in the host's field. */
const looks = [
  { name: "a short plan", source: marked },
  { name: "a long plan", source: markedLong },
];

const themes = ["soft", "graphic"];

function drawn({ source, caret, field, page }) {
  const container = document.createElement("div");
  document.body.append(container);
  const root = createRoot(container);
  const value = read(source, {});
  act(() =>
    root.render(
      page
        ? createElement(Drawing.make, { value, options: {} })
        : createElement(Editor.make, { value, options: {}, onChange: () => {}, field: field ? Field : undefined }),
    ),
  );
  if (caret !== undefined) {
    const field = container.querySelector(`span[data-field="${caret}"]`);
    if (field === null) throw new Error(`No field "${caret}" to put the caret in`);
    act(() => field.focus());
  }
  const html = container.innerHTML;
  act(() => root.unmount());
  container.remove();
  return html;
}

function chrome() {
  const candidates = [
    process.env.CHROME,
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    ...["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"].map((name) => {
      const found = spawnSync("which", [name], { encoding: "utf8" });
      return found.status === 0 ? found.stdout.trim() : undefined;
    }),
  ];
  const found = candidates.find((path) => path && existsSync(path));
  if (found === undefined) {
    console.error("The hit check needs Chrome or Chromium. Install one, or set CHROME to its path.");
    process.exit(2);
  }
  return found;
}

// A stylesheet of this package, or of @minidoc/blocks.
const css = (path) =>
  pathToFileURL(fileURLToPath(path.startsWith("@") ? import.meta.resolve(path) : new URL(path, import.meta.url))).href;

// The script the page runs: every field and act, scrolled into view, must
// be what lies at its centre, or hold it.
const probe = `
const misses = [];
let checked = 0;
for (const element of document.querySelectorAll("[data-field], [data-act], textarea")) {
  if (element.getClientRects().length === 0) continue;
  element.scrollIntoView({ block: "center", inline: "center" });
  const box = element.getClientRects()[0];
  const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
  checked++;
  if (hit !== element && !element.contains(hit)) {
    const where = element.closest("[data-case]");
    const name = element.dataset.field ?? (element.dataset.act === undefined ? "a text area" : "act " + element.textContent);
    const by = hit === null ? "nothing" : hit.tagName.toLowerCase() + (hit.className ? "." + String(hit.className).split(" ").join(".") : "");
    misses.push(where.dataset.case + ": " + name + " takes no click, " + by + " does");
  }
}

// Each text in the host's field, against the same text on the static page:
// the element that holds the field, found by its tag and classes, must have
// the same size, and each of its texts the same font, colour and place.
const differences = [];
let compared = 0;
const same = (a, b) => Math.abs(a - b) <= 0.5;
const look = ["fontFamily", "fontSize", "fontWeight", "fontStyle", "lineHeight", "letterSpacing", "color"];
const texts = (holder) => {
  const found = [];
  const walker = document.createTreeWalker(holder, NodeFilter.SHOW_TEXT);
  for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
    if (node.textContent.trim() === "" || node.parentElement.closest("button, [data-act], input")) continue;
    // Word by word: the host's field keeps typed spaces, so a space at the
    // end of a wrapped line has a box there, and none on the page.
    const rects = [];
    for (const word of node.textContent.matchAll(/\S+/g)) {
      const range = document.createRange();
      range.setStart(node, word.index);
      range.setEnd(node, word.index + word[0].length);
      rects.push(...range.getClientRects());
    }
    found.push({ node, rects });
  }
  return found;
};
for (const pair of document.querySelectorAll("[data-look]")) {
  const [page, edited] = pair.querySelectorAll("[data-case]");
  const name = pair.dataset.look;
  // An empty text's holder, such as an empty message's place drawn only
  // where the person may edit, has no twin on the page: it is not counted.
  const like = (element, within) =>
    [...within.querySelectorAll(element.localName)].filter(
      (other) => other.className === element.className && !other.closest("[data-field]") && other.textContent !== "",
    );
  for (const field of edited.querySelectorAll("span[data-field]")) {
    if (field.querySelector("[contenteditable]") === null || field.textContent === "") continue;
    const holder = field.parentElement;
    const index = like(holder, edited).indexOf(holder);
    const twin = like(holder, page)[index];
    const where = name + ": " + field.dataset.field;
    if (twin === undefined) { differences.push(where + " has no text on the page"); continue; }
    holder.scrollIntoView({ block: "center" });
    const at = holder.getBoundingClientRect();
    const on = twin.getBoundingClientRect();
    compared++;
    if (!same(at.width, on.width) || !same(at.height, on.height)) {
      differences.push(where + ": its " + holder.localName + " is " + at.width + "×" + at.height + ", " + on.width + "×" + on.height + " on the page");
    }
    const mine = texts(holder);
    const theirs = texts(twin);
    const words = (list) => list.map((t) => t.node.textContent.trim());
    if (words(mine).join("|") !== words(theirs).join("|")) {
      differences.push(where + ": the texts " + JSON.stringify(words(mine)) + " are " + JSON.stringify(words(theirs)) + " on the page");
      continue;
    }
    mine.forEach((text, i) => {
      const other = theirs[i];
      const style = getComputedStyle(text.node.parentElement);
      const theirStyle = getComputedStyle(other.node.parentElement);
      for (const property of look) {
        if (style[property] !== theirStyle[property]) {
          differences.push(where + ": “" + text.node.textContent + "” has " + property + " " + style[property] + ", " + theirStyle[property] + " on the page");
        }
      }
      const placed = text.rects.map((r) => [r.left - at.left, r.top - at.top, r.width, r.height]);
      const placedThere = other.rects.map((r) => [r.left - on.left, r.top - on.top, r.width, r.height]);
      const moved = placed.length !== placedThere.length || placed.some((box, j) => box.some((v, k) => !same(v, placedThere[j][k])));
      if (moved) {
        differences.push(where + ": “" + text.node.textContent + "” is at " + JSON.stringify(placed.map((b) => b.map(Math.round))) + ", " + JSON.stringify(placedThere.map((b) => b.map(Math.round))) + " on the page");
      }
    });
  }
}
// A long plan's side list is a third of the plan's width.
let measured = 0;
for (const list of document.querySelectorAll(".plan--long .plan__stages")) {
  const stage = list.querySelector(".plan__stage");
  if (stage === null || stage.getClientRects().length === 0) continue;
  const third = list.getBoundingClientRect().width / 3;
  const width = stage.getBoundingClientRect().width;
  measured++;
  if (Math.abs(width - third) > 1) {
    differences.push(list.closest("[data-case]").dataset.case + ": the side list is " + width + "px wide, a third is " + third + "px");
  }
}
document.getElementById("hits").textContent = JSON.stringify({ checked, misses, compared, measured, differences });
`;

const page = `<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="${css("@minidoc/blocks/blocks.css")}">
${themes.map((theme) => `<link rel="stylesheet" href="${css(`@minidoc/blocks/themes/${theme}.css`)}">`).join("\n")}
<link rel="stylesheet" href="${css("../live.css")}">
<style>body { margin: 0; padding: 24px; font: 16px/1.6 sans-serif; } [data-case] { max-width: 60rem; margin-bottom: 3em; }</style>
</head><body>
${themes
  .flatMap((theme) =>
    cases.map((one) => `<div data-blocks-theme="${theme}" data-case="${one.name}, ${theme}">${drawn(one)}</div>`),
  )
  .join("\n")}
${themes
  .flatMap((theme) =>
    looks.map(
      (one, i) => `<div data-look="${one.name}, ${theme}">
<div data-blocks-theme="${theme}" data-case="${one.name} on a page, ${theme}">${drawn({ ...one, page: true }).replaceAll('name="plan-', `name="look-${theme}-${i}-plan-`)}</div>
<div data-blocks-theme="${theme}" data-case="${one.name} in the host's field, ${theme}">${drawn({ ...one, field: true })}</div>
</div>`,
    ),
  )
  .join("\n")}
<pre id="hits"></pre>
<script>${probe}</script>
</body></html>`;

const folder = mkdtempSync(join(tmpdir(), "minidoc-hit-"));
const file = join(folder, "hit.html");
writeFileSync(file, page);
const dumped = execFileSync(
  chrome(),
  ["--headless=new", "--disable-gpu", "--allow-file-access-from-files", "--window-size=1400,900", "--dump-dom", pathToFileURL(file).href],
  { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
);
const found = /<pre id="hits">([^<]*)<\/pre>/.exec(dumped);
if (found === null || found[1] === "") {
  console.error(`The hit check found no result in Chrome's page: ${file}`);
  process.exit(1);
}
const { checked, misses, compared, measured, differences } = JSON.parse(found[1].replaceAll("&quot;", '"').replaceAll("&amp;", "&"));
if (misses.length > 0) {
  console.error(`${misses.length} of ${checked} fields and acts take no click:\n${misses.map((m) => `  ${m}`).join("\n")}`);
}
if (differences.length > 0) {
  console.error(`${differences.length} differences between the host's field and the page:\n${differences.map((d) => `  ${d}`).join("\n")}`);
}
if (misses.length > 0 || differences.length > 0) {
  console.error(`The page: ${file}`);
  process.exit(1);
}
console.log(`${checked} fields and acts take their click, in ${cases.length + looks.length} plans and ${themes.length} themes.`);
console.log(`${compared} texts in the host's field look as on the page, in ${looks.length} plans and ${themes.length} themes.`);
console.log(`${measured} long plans give their side list a third of their width.`);
