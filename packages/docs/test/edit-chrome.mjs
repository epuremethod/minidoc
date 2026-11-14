// The dev page as an editor, in a real Chrome: what jsdom cannot show.
// Typing keeps the caret and writes the file; `::: note ` makes a callout
// written as minidoc's, and ```` ```js ```` a code block written as a fence; a drawing opens its source in the panel and follows
// each key; the panel's card moves, grows, and keeps both in
// localStorage; a press outside it closes it; a failed save shows a banner
// that stays, keeps the edits, asks before a reload, and offers them back;
// a save by another program reloads the page; and the edited text looks as
// on the static page, word by word.
//
// It runs on a copy of the docs, beside them in `packages/`, so the real
// files are never written. Chrome is driven through its DevTools protocol,
// on Node's own WebSocket. Run it by hand: `pnpm docs:edit-check`.
import { spawn, spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dev } from "@minidoc/core";
import { bundled } from "../src/bundle.mjs";

const docs = fileURLToPath(new URL("../", import.meta.url));
const copy = mkdtempSync(join(docs, "..", ".edit-check-"));
const results = [];
const report = (name, ok, detail = "") => {
  results.push(ok);
  console.log(`${ok ? "ok  " : "FAIL"} ${name}${detail ? `: ${detail}` : ""}`);
};
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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
    console.error("The edit check needs Chrome or Chromium. Install one, or set CHROME to its path.");
    process.exit(2);
  }
  return found;
}

const freePort = () =>
  new Promise((resolve) => {
    const server = createServer().listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });

/** Chrome, and one page in it, through the DevTools protocol. */
async function browse() {
  const profile = mkdtempSync(join(tmpdir(), "minidoc-edit-check-"));
  const child = spawn(chrome(), [
    "--headless=new",
    "--disable-gpu",
    "--remote-debugging-port=0",
    `--user-data-dir=${profile}`,
    "--window-size=1300,1000",
    "about:blank",
  ], { stdio: "ignore" });
  const file = join(profile, "DevToolsActivePort");
  for (let i = 0; i < 100 && !existsSync(file); i++) await pause(100);
  const [port, path] = readFileSync(file, "utf8").trim().split("\n");
  const socket = new WebSocket(`ws://127.0.0.1:${port}${path}`);
  await new Promise((resolve) => socket.addEventListener("open", resolve, { once: true }));
  let id = 0;
  const waiting = new Map();
  const listeners = [];
  socket.addEventListener("message", ({ data }) => {
    const message = JSON.parse(data);
    if (message.id && waiting.has(message.id)) {
      const { resolve, reject } = waiting.get(message.id);
      waiting.delete(message.id);
      message.error ? reject(new Error(message.error.message)) : resolve(message.result);
    } else if (message.method) {
      for (const listener of listeners) listener(message);
    }
  });
  const send = (method, params = {}, sessionId) =>
    new Promise((resolve, reject) => {
      waiting.set(++id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params, ...(sessionId && { sessionId }) }));
    });
  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
  const on = (method, params) => send(method, params, sessionId);
  await on("Page.enable");
  await on("Runtime.enable");
  await on("Emulation.setDeviceMetricsOverride", { width: 1300, height: 1000, deviceScaleFactor: 1, mobile: false });
  const loaded = () =>
    new Promise((resolve) => {
      const listener = (message) => {
        if (message.method === "Page.loadEventFired" && message.sessionId === sessionId) {
          listeners.splice(listeners.indexOf(listener), 1);
          resolve();
        }
      };
      listeners.push(listener);
    });
  // A dialog of the page, such as the one before leaving with unsaved
  // edits, is noted and answered: leave, unless told to stay.
  const dialogs = [];
  let staying = false;
  listeners.push((message) => {
    if (message.method === "Page.javascriptDialogOpening" && message.sessionId === sessionId) {
      dialogs.push(message.params.type);
      on("Page.handleJavaScriptDialog", { accept: !staying }).catch(() => {});
    }
  });
  const evaluate = async (expression) => {
    const { result, exceptionDetails } = await on("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (exceptionDetails) throw new Error(`${expression.slice(0, 80)}: ${exceptionDetails.exception?.description ?? exceptionDetails.text}`);
    return result.value;
  };
  return {
    evaluate,
    loaded,
    dialogs,
    /** Answer the next dialogs by staying on the page, or by leaving it. */
    stay: (yes) => { staying = yes },
    /** Give the page another window size. */
    resize: (width, height) => on("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: 1, mobile: false }),
    async go(url) {
      const done = loaded();
      await on("Page.navigate", { url });
      await done;
    },
    /** Wait until `expression` is true, or give up. */
    async until(expression, ms = 5000) {
      const limit = Date.now() + ms;
      while (Date.now() < limit) {
        if (await evaluate(expression).catch(() => false)) return true;
        await pause(50);
      }
      return false;
    },
    async click(selector) {
      const at = await evaluate(`(() => {
        const element = document.querySelector(${JSON.stringify(selector)})
        element.scrollIntoView({ block: "center" })
        const box = element.getBoundingClientRect()
        return { x: box.left + box.width / 2, y: box.top + Math.min(box.height / 2, 20) }
      })()`);
      for (const type of ["mousePressed", "mouseReleased"]) {
        await on("Input.dispatchMouseEvent", { type, x: at.x, y: at.y, button: "left", clickCount: 1 });
      }
      await pause(120);
    },
    /** Press the mouse at `from`, move it in steps to `to`, and release it there. */
    async drag(from, to) {
      await on("Input.dispatchMouseEvent", { type: "mousePressed", x: from.x, y: from.y, button: "left", buttons: 1, clickCount: 1 });
      for (let step = 1; step <= 5; step++) {
        const x = from.x + ((to.x - from.x) * step) / 5;
        const y = from.y + ((to.y - from.y) * step) / 5;
        await on("Input.dispatchMouseEvent", { type: "mouseMoved", x, y, button: "left", buttons: 1 });
      }
      await on("Input.dispatchMouseEvent", { type: "mouseReleased", x: to.x, y: to.y, button: "left", buttons: 0, clickCount: 1 });
      await pause(120);
    },
    type: (text) => on("Input.insertText", { text }),
    async press(key, code, keyCode, text) {
      for (const type of text ? ["keyDown", "keyUp"] : ["rawKeyDown", "keyUp"]) {
        await on("Input.dispatchKeyEvent", { type, key, code, windowsVirtualKeyCode: keyCode, ...(type === "keyDown" && { text }) });
      }
    },
    async close() {
      socket.close();
      const exited = new Promise((resolve) => child.once("exit", resolve));
      child.kill();
      await exited;
      rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    },
  };
}

/**
 Each text the editor holds, by its order on the page: its words, with
 the font, the colour and the box of each, from the top left of the text.
 `texts` names the texts of the page.
*/
const looks = (texts) => `(() => {
  const out = []
  for (const block of document.querySelectorAll(${JSON.stringify(texts)})) {
    const box = block.getBoundingClientRect()
    const words = []
    const walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT)
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      const style = getComputedStyle(node.parentElement)
      for (const m of node.data.matchAll(/\\S+/g)) {
        const range = document.createRange()
        range.setStart(node, m.index)
        range.setEnd(node, m.index + m[0].length)
        const r = range.getBoundingClientRect()
        words.push([m[0], style.fontFamily, style.fontSize, style.fontWeight, style.fontStyle, style.color,
          Math.round(r.left - box.left), Math.round(r.top - box.top), Math.round(r.width), Math.round(r.height)].join(" "))
      }
    }
    out.push({ text: block.textContent.replace(/\\s+/g, " ").trim(), words })
  }
  return out
})()`;

try {
  // The copy: the docs' sources and content, the site's own modules, and
  // the static build, made before the editor's.
  for (const part of ["content", "src", "assets", "package.json"]) cpSync(join(docs, part), join(copy, part), { recursive: true });
  symlinkSync(join(docs, "node_modules"), join(copy, "node_modules"));
  const build = spawnSync(process.execPath, ["src/build.mjs"], { cwd: copy, encoding: "utf8", env: { ...process.env, MINIDOC_EDIT: "" } });
  if (build.status !== 0) throw new Error(`The static build failed: ${build.stderr}`);
  cpSync(join(copy, "dist"), join(copy, "static"), { recursive: true });

  process.env.MINIDOC_EDIT = "1";
  await bundled(join(copy, "dist"));
  const port = await freePort();
  const server = await dev({ root: copy, glob: "content/config.yaml", build: "src/build.mjs", edit: ["content"], port });
  const page = await browse();
  const site = `http://127.0.0.1:${port}`;
  const file = (path) => readFileSync(join(copy, "content", path), "utf8");
  // Each section mounts on its own: wait until every one has its editor.
  const mounted = () =>
    page.until(`(() => { const all = document.querySelectorAll("[data-minidoc-edit]"); return all.length > 0 && [...all].every(e => e.querySelector(".editor")) })()`);

  try {
    // Typing in a chapter.
    await page.go(`${site}/`);
    await mounted();
    await page.evaluate(`window.stays = true`);
    const first = `#one-page .editor > p:not(.display)`;
    await page.click(first);
    await page.evaluate(`(() => {
      const block = document.querySelector(${JSON.stringify(first)})
      const range = document.createRange()
      range.selectNodeContents(block)
      range.collapse(false)
      getSelection().removeAllRanges()
      getSelection().addRange(range)
    })()`);
    await page.type(" Typed here.");
    await pause(1200);
    const caret = await page.evaluate(`(() => {
      const s = getSelection()
      return s.focusNode && document.querySelector(${JSON.stringify(first)}).contains(s.focusNode) && s.focusNode.data.slice(0, s.focusOffset).endsWith("Typed here.")
    })()`);
    report(
      "typing in a chapter changes its file, and the caret stays",
      file("guide/02-one-page.md").includes("right\ntitle. Typed here.") && caret && (await page.evaluate(`window.stays === true`)),
      file("guide/02-one-page.md").split("\n").slice(8, 10).join(" / "),
    );

    // A drawing opens its source on a second click: the first selects its
    // block whole. A block the editor still holds opens on the first.
    const sourceOpen = `!!document.querySelector(".edit-pane textarea.pane__source")`;
    const openSource = async (selector) => {
      await page.click(selector);
      if (await page.until(sourceOpen, 600)) return true;
      await page.click(selector);
      return page.until(sourceOpen);
    };

    // The sequence through the panel.
    const opened = await openSource(`#live .editor .sequence`);
    await page.evaluate(`(() => {
      const box = document.querySelector(".edit-pane textarea.pane__source")
      box.focus()
      const at = box.value.indexOf("save a file")
      box.setSelectionRange(at, at + "save a file".length)
    })()`);
    await page.type("save a page");
    const follows = await page.until(`document.querySelector("#live .editor .sequence").textContent.includes("save a page")`, 2000);
    await pause(1000);
    await page.press("Escape", "Escape", 27);
    const left = await page.until(`!document.querySelector(".edit-pane textarea.pane__source") && !!document.activeElement.closest(".editor")`, 2000);
    report(
      "a click on the sequence opens its source in the panel, the drawing follows each key, and Escape gives the caret back",
      opened && follows && file("guide/11-live.md").includes("you -> dev  save a page") && left,
      `opened ${opened}, follows ${follows}, left ${left}`,
    );

    // The panel's card, moved by its bar and made bigger by its grip, opens
    // where the person left it after a reload.
    const card = `(() => { const r = document.querySelector(".edit-pane").getBoundingClientRect(); return { left: Math.round(r.left), top: Math.round(r.top), width: Math.round(r.width), height: Math.round(r.height) } })()`;
    const centre = (selector) => `(() => { const r = document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 } })()`;
    const near = (a, b) => ["left", "top", "width", "height"].every((key) => Math.abs(a[key] - b[key]) <= 1);
    await openSource(`#live .editor .sequence`);
    const opening = await page.evaluate(card);
    const bar = await page.evaluate(centre(".edit-pane__name"));
    await page.drag(bar, { x: bar.x - 200, y: bar.y - 100 });
    const moved = await page.evaluate(card);
    const grip = await page.evaluate(centre(".edit-pane__grip"));
    await page.drag(grip, { x: grip.x - 100, y: grip.y - 100 });
    const grown = await page.evaluate(card);
    const kept = await page.evaluate(`document.activeElement === document.querySelector(".edit-pane textarea.pane__source")`);
    await page.press("Escape", "Escape", 27);
    await page.go(`${site}/`);
    await mounted();
    await openSource(`#live .editor .sequence`);
    const again = await page.evaluate(card);
    await page.press("Escape", "Escape", 27);
    report(
      "the panel's card moves by its bar, grows by its top-left grip, keeps the caret in the source, and opens at the same place and size after a reload",
      near(moved, { ...opening, left: opening.left - 200, top: opening.top - 100 }) &&
        near(grown, { left: moved.left - 100, top: moved.top - 100, width: moved.width + 100, height: moved.height + 100 }) &&
        kept &&
        near(again, grown),
      `opening ${JSON.stringify(opening)}, moved ${JSON.stringify(moved)}, grown ${JSON.stringify(grown)}, kept ${kept}, again ${JSON.stringify(again)}`,
    );

    // A press outside the card and the open block closes the panel; a
    // press in the card keeps it. A press on the open block hides its source,
    // as the editor's third click does, and the next one shows it again.
    const open = `!!document.querySelector(".edit-pane textarea.pane__source")`;
    await openSource(`#live .editor .sequence`);
    await page.click(`.edit-pane textarea.pane__source`);
    const inCard = await page.evaluate(open);
    await page.click(`#live .editor .sequence`);
    const hidden = await page.until(`!(${open})`, 2000);
    await page.click(`#live .editor .sequence`);
    const onBlock = hidden && (await page.until(open, 2000));
    await page.click(`.contents__label`);
    const byMenu = await page.until(`!(${open})`, 2000);
    await openSource(`#live .editor .sequence`);
    await page.click(`#one-page .editor > p:not(.display)`);
    const byText = await page.until(`!(${open})`, 2000);
    const caretThere = await page.evaluate(`!!getSelection().focusNode && !!document.querySelector("#one-page .editor").contains(getSelection().focusNode)`);
    report(
      "a press outside the panel's card and the open block closes the panel, a press on the block hides and shows its source, and a press in another section puts the caret there",
      inCard && onBlock && byMenu && byText && caretThere,
      `in the card ${inCard}, on the block ${onBlock}, by the menu ${byMenu}, by the text ${byText}, caret there ${caretThere}`,
    );

    // A callout typed in place.
    await page.go(`${site}/`);
    await mounted();
    await page.click(first);
    await page.evaluate(`(() => {
      const block = document.querySelector(${JSON.stringify(first)})
      const range = document.createRange()
      range.selectNodeContents(block)
      range.collapse(false)
      getSelection().removeAllRanges()
      getSelection().addRange(range)
    })()`);
    await page.press("Enter", "Enter", 13, "\r");
    await page.type("::: note");
    await page.type(" ");
    const made = await page.until(`!!document.querySelector("#one-page .editor .callout--note .callout__byline")`, 2000);
    await page.type("Anna");
    await page.press("Tab", "Tab", 9);
    await page.type("2026-11-07");
    await page.press("Tab", "Tab", 9);
    await page.type("Mara keeps it open.");
    await pause(1200);
    const label = await page.evaluate(`document.querySelector("#one-page .editor .callout--note .callout__label")?.textContent ?? ""`);
    const callout = `::: note "Anna" 2026-11-07\nMara keeps it open.\n:::`;
    report(
      "`::: note ` and a space makes a callout, Tab goes from its author to its date and its body, and the file holds it",
      made && label === "Note" && file("guide/02-one-page.md").includes(callout),
      `made ${made}, label ${JSON.stringify(label)}, file ${JSON.stringify(file("guide/02-one-page.md").split("\n").slice(8, 16).join(" / "))}`,
    );

    // A comment typed in place, then removed by its ×.
    await page.press("Enter", "Enter", 13, "\r");
    await page.press("Enter", "Enter", 13, "\r");
    await page.type("::: comment");
    await page.type(" ");
    const comment = await page.until(`!!document.querySelector("#one-page .editor .callout--comment .callout__remove")`, 2000);
    await page.press("Tab", "Tab", 9);
    await page.press("Tab", "Tab", 9);
    await page.type("Check the date.");
    await pause(1200);
    const written = file("guide/02-one-page.md").includes("::: comment\nCheck the date.\n:::");
    // On a wide screen it is as wide as the text and shifted to the right;
    // on a narrow one it keeps the column. Its × and its byline share a row.
    const place = `(() => {
      const text = document.querySelector("#one-page .editor").getBoundingClientRect()
      const comment = document.querySelector("#one-page .editor .callout--comment")
      const box = comment.getBoundingClientRect()
      const remove = comment.querySelector(".callout__remove").getBoundingClientRect()
      const byline = comment.querySelector(".callout__byline").getBoundingClientRect()
      return {
        shift: Math.round(box.left - text.left),
        same: Math.abs(box.width - text.width) <= 1,
        row: Math.abs(remove.top + remove.height / 2 - (byline.top + byline.height / 2)) <= 4,
      }
    })()`;
    const wide = await page.evaluate(place);
    await page.resize(800, 1000);
    await pause(200);
    const narrow = await page.evaluate(place);
    await page.resize(1300, 1000);
    await pause(200);
    if (comment) await page.click("#one-page .editor .callout--comment .callout__remove");
    const gone = await page.until(`!document.querySelector("#one-page .editor .callout--comment")`, 2000);
    await pause(1200);
    report(
      "`::: comment ` makes a comment with a × in its head, as wide as the text and shifted right on a wide screen, in the column on a narrow one, with the × and the byline on one row, and a click on the × removes the block from the page and the file",
      comment && written && wide.shift === 48 && wide.same && wide.row && narrow.shift === 0 && narrow.same && gone && !file("guide/02-one-page.md").includes("::: comment") && file("guide/02-one-page.md").includes(callout),
      `×  ${comment}, written ${written}, wide ${JSON.stringify(wide)}, narrow ${JSON.stringify(narrow)}, gone ${gone}, file ${JSON.stringify(file("guide/02-one-page.md").split("\n").slice(8, 20).join(" / "))}`,
    );

    // A code block typed in place.
    const last = `#one-page .editor .callout--note > p:last-child`;
    await page.click(last);
    await page.evaluate(`(() => {
      const block = document.querySelector(${JSON.stringify(last)})
      const range = document.createRange()
      range.selectNodeContents(block)
      range.collapse(false)
      getSelection().removeAllRanges()
      getSelection().addRange(range)
    })()`);
    await page.press("Enter", "Enter", 13, "\r");
    await page.press("Enter", "Enter", 13, "\r");
    await page.type("```js");
    await page.press("Enter", "Enter", 13, "\r");
    const coded = await page.until(`!!document.querySelector("#one-page .editor pre.code")`, 2000);
    await page.type("await dev()");
    await page.press("Enter", "Enter", 13, "\r");
    await page.type("  await build()");
    await pause(1200);
    const fence = "```js\nawait dev()\n  await build()\n```";
    report(
      "```js and Enter makes a code block after the callout, its lines keep their spaces, and the file holds its fence",
      coded && file("guide/02-one-page.md").includes(fence),
      `made ${coded}, file ${JSON.stringify(file("guide/02-one-page.md").split("\n").slice(8, 22).join(" / "))}`,
    );

    // A drawing typed in place: its fence opens its source in the panel.
    await page.click(first);
    await page.evaluate(`(() => {
      const range = document.createRange()
      range.selectNodeContents(document.querySelector(${JSON.stringify(first)}))
      range.collapse(false)
      getSelection().removeAllRanges()
      getSelection().addRange(range)
    })()`);
    await page.press("Enter", "Enter", 13, "\r");
    await page.type("::: states");
    await page.type(" ");
    // The source opens with the caret on the drawing's empty line.
    const paned = await page.until(`(() => {
      const box = document.querySelector(".edit-pane textarea.pane__source")
      return box?.value === "::: states\\n\\n:::" && document.activeElement === box && box.selectionStart === 11 && box.selectionEnd === 11
    })()`, 2000);
    await page.type("draft review");
    await page.press("Enter", "Enter", 13, "\r");
    await page.press("Enter", "Enter", 13, "\r");
    await page.type("draft -> review  submit");
    const shown = await page.until(`(document.querySelector("#one-page .editor .states")?.textContent ?? "").includes("submit")`, 2000);
    await pause(1200);
    await page.press("Escape", "Escape", 27);
    const states = "::: states\ndraft review\n\ndraft -> review  submit\n:::";
    report(
      "`::: states` and a space makes a drawing and opens its source in the panel, the drawing follows the grid, and the file holds it",
      paned && shown && file("guide/02-one-page.md").includes(states),
      `paned ${paned}, shown ${shown}, file ${JSON.stringify(file("guide/02-one-page.md").split("\n").slice(8, 16).join(" / "))}`,
    );

    // A drawing selected whole shows as one block with an outline, and its
    // text takes no highlight.
    await page.click("#one-page .editor .states svg");
    const held = await page.until(`(() => {
      const held = document.querySelector("#one-page .editor [data-selected]")
      const text = held?.querySelector("svg text")
      return !!text && getComputedStyle(held).outlineStyle !== "none"
        && getComputedStyle(text, "::selection").backgroundColor === "rgba(0, 0, 0, 0)"
    })()`, 2000);
    report(
      "a click on a drawing selects its block whole: the block shows an outline, and its text no highlight",
      held,
      `held ${held}, selected ${await page.evaluate(`document.querySelectorAll("#one-page .editor [data-selected]").length`)}`,
    );

    // A failed save. The page's PUT is refused while `window.refuse` is set.
    const typeAtEnd = async (selector, text) => {
      await page.click(selector);
      await page.evaluate(`(() => {
        const range = document.createRange()
        range.selectNodeContents(document.querySelector(${JSON.stringify(selector)}))
        range.collapse(false)
        getSelection().removeAllRanges()
        getSelection().addRange(range)
      })()`);
      await page.type(text);
      await pause(1200);
    };
    const refusing = `(() => {
      const real = window.fetch
      window.refuse = true
      window.fetch = (url, init) => init?.method === "PUT" && window.refuse ? Promise.resolve(new Response("disk full", { status: 500 })) : real(url, init)
    })()`;
    const banner = (text) => `[...document.querySelectorAll(".edit-alert[role=alert]")].some(b => b.textContent.includes(${JSON.stringify(text)}))`;
    const noBanner = `!document.querySelector(".edit-alert")`;
    const draft = (text) => `Object.keys(localStorage).some(k => k.startsWith("minidoc-draft:") && localStorage.getItem(k).includes(${JSON.stringify(text)}))`;
    const act = async (label) => {
      await page.evaluate(`[...document.querySelectorAll(".edit-alert__act")].find(b => b.textContent === ${JSON.stringify(label)}).scrollIntoView()`);
      const at = await page.evaluate(`(() => { const r = [...document.querySelectorAll(".edit-alert__act")].find(b => b.textContent === ${JSON.stringify(label)}).getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 } })()`);
      await page.drag(at, at);
    };

    await page.evaluate(refusing);
    await typeAtEnd(first, " Kept.");
    const alerted = await page.until(banner("is not saved (500): disk full"), 2000);
    await pause(6500);
    const remains = await page.evaluate(banner("is not saved (500)"));
    const drafted = await page.evaluate(draft("Kept.")) && !file("guide/02-one-page.md").includes("Kept.");
    await page.evaluate(`window.refuse = false`);
    await act("Retry");
    const retried = await page.until(`${noBanner} && !${draft("Kept.")}`, 3000);
    report(
      "a failed save shows a banner that stays, the edits stay in the browser, and Retry writes them",
      alerted && remains && drafted && retried && file("guide/02-one-page.md").includes("Kept."),
      `alerted ${alerted}, remains ${remains}, drafted ${drafted}, retried ${retried}`,
    );

    // A reload with edits that are not on disk asks first, and the page
    // offers them back.
    await page.evaluate(refusing);
    await typeAtEnd(first, " Restored.");
    const before = page.dialogs.length;
    const back = page.loaded();
    await page.evaluate(`setTimeout(() => location.reload(), 0)`);
    await Promise.race([back, pause(5000)]);
    await mounted();
    const asked = page.dialogs.slice(before).includes("beforeunload");
    const offered = await page.until(banner("has edits from before the page reloaded"), 3000);
    await act("Restore my edits");
    const restored = await page.until(`${noBanner} && !${draft("Restored.")}`, 3000);
    report(
      "a reload with unsaved edits asks first, and the page offers them back after it",
      asked && offered && restored && file("guide/02-one-page.md").includes("Restored."),
      `asked ${asked}, offered ${offered}, restored ${restored}`,
    );

    // A file changed on disk while the person's edits are not saved: the
    // reload asks first, the person stays, and a conflict banner replaces
    // the reload.
    await page.evaluate(refusing);
    await typeAtEnd(first, " Mine.");
    page.stay(true);
    const asks = page.dialogs.length;
    writeFileSync(join(copy, "content", "guide/02-one-page.md"), `${file("guide/02-one-page.md")}\nA line from another program.\n`);
    await page.until(`false`, 2500);
    page.stay(false);
    const stayed = page.dialogs.slice(asks).includes("beforeunload") && (await page.evaluate(`window.refuse === true`));
    await page.evaluate(`window.refuse = false`);
    await act("Retry");
    const conflict = await page.until(banner("changed on disk while you edited it"), 3000);
    await act("Keep my text");
    const settled = await page.until(noBanner, 3000);
    const mine = file("guide/02-one-page.md");
    report(
      "a file changed on disk under unsaved edits shows a conflict banner, and Keep my text writes them over it",
      stayed && conflict && settled && mine.includes("Mine.") && !mine.includes("A line from another program."),
      `stayed ${stayed}, conflict ${conflict}, settled ${settled}`,
    );

    // A save by another program.
    await page.evaluate(`window.stays = true`);
    const reloaded = page.loaded();
    writeFileSync(join(copy, "content", "guide/13-onward.md"), `${file("guide/13-onward.md")}\nA line from elsewhere.\n`);
    await Promise.race([reloaded, pause(8000)]);
    await mounted();
    const note = await page.until(`(document.querySelector(".edit-note")?.textContent || "").includes("reloaded")`, 3000);
    report(
      "a save by another program reloads the page, with a message",
      (await page.evaluate(`window.stays !== true`)) && note && (await page.evaluate(`document.body.textContent.includes("A line from elsewhere.")`)),
    );

    // The look, against the static page.
    await page.go(pathToFileURL(join(copy, "static", "index.html")).href);
    const still = await page.evaluate(looks(".prose > p:not(.chapter__refs), .prose > h3, .prose > ul > li"));
    await page.go(`${site}/`);
    await mounted();
    await pause(500);
    const edited = await page.evaluate(looks(".editor > p:not(.display), .editor > h3, .editor > ul > li"));
    let same = 0;
    let skipped = 0;
    const misses = [];
    let j = 0;
    for (const text of edited) {
      // The static page renders the brace escapes, and the editor shows them as typed.
      const match = still.slice(j).findIndex((s) => s.text === text.text);
      if (match < 0) {
        skipped++;
        continue;
      }
      j += match + 1;
      const known = still[j - 1];
      const differs = text.words.findIndex((word, i) => word !== known.words[i]);
      if (differs < 0 && text.words.length === known.words.length) same++;
      else misses.push(`${text.text.slice(0, 40)}…: ${text.words[differs]} / ${known.words[differs]}`);
    }
    report(
      "the edited text looks as on the static page, word by word",
      misses.length === 0 && same > 50,
      `${same} texts alike, ${skipped} shown with their brace escapes${misses.length ? `\n  ${misses.slice(0, 8).join("\n  ")}` : ""}`,
    );

    // A table and an image line in the file.
    const dot = "![A grey dot](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNoAAAAggCBd81ytgAAAABJRU5ErkJggg==)";
    writeFileSync(join(copy, "content", "guide/02-one-page.md"), `${file("guide/02-one-page.md")}\n${dot}\n\n| Space | Compact |\n| --- | --- |\n| The circle | yes |\n`);
    await pause(1500);
    await page.go(`${site}/`);
    await mounted();
    const cell = `#one-page .editor table td:last-child`;
    const drawn = await page.until(`!!document.querySelector(${JSON.stringify(cell)})`, 3000);
    await page.click(cell);
    await page.evaluate(`(() => {
      const range = document.createRange()
      range.selectNodeContents(document.querySelector(${JSON.stringify(cell)}))
      range.collapse(false)
      getSelection().removeAllRanges()
      getSelection().addRange(range)
    })()`);
    await page.type(" here");
    await pause(1200);
    report(
      "a table in a file is drawn, and a word typed in a cell changes its row",
      drawn && file("guide/02-one-page.md").includes("| The circle | yes here |"),
      `drawn ${drawn}, row ${file("guide/02-one-page.md").trimEnd().split("\n").at(-1)}`,
    );
    const image = await page.evaluate(`(() => {
      const img = document.querySelector("#one-page .editor .edit-image img")
      return img ? img.alt + " " + img.naturalWidth + "x" + img.naturalHeight : "none"
    })()`);
    report(
      "an image line is drawn as its image, and a word typed elsewhere keeps its line",
      image === "A grey dot 1x1" && file("guide/02-one-page.md").includes(`\n${dot}\n`),
      image,
    );
  } finally {
    await page.close();
    server.stop();
  }
} finally {
  rmSync(copy, { recursive: true, force: true });
}

const failed = results.filter((ok) => !ok).length;
console.log(failed ? `${failed} of ${results.length} checks failed.` : `${results.length} checks pass in Chrome.`);
process.exit(failed ? 1 : 0);
