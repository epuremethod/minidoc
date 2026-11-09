// The dev page as an editor, in a real Chrome: what jsdom cannot show.
// Typing keeps the caret and writes the file; `::: note ` makes a callout
// written as minidoc's, and ```` ```js ```` a code block written as a fence; a drawing opens its source in the panel and follows
// each key; a save by another program reloads the
// page; and the edited text looks as on the static page, word by word.
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
import { dev } from "@epure/minidoc";
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
  const evaluate = async (expression) => {
    const { result, exceptionDetails } = await on("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (exceptionDetails) throw new Error(`${expression.slice(0, 80)}: ${exceptionDetails.exception?.description ?? exceptionDetails.text}`);
    return result.value;
  };
  return {
    evaluate,
    loaded,
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
  const mounted = () => page.until(`document.querySelectorAll("[data-minidoc-edit] .editor").length > 0`);

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

    // The sequence through the panel.
    await page.click(`#live .editor .sequence`);
    const opened = await page.until(`!!document.querySelector(".edit-pane .pane__source")`);
    await page.evaluate(`(() => {
      const box = document.querySelector(".edit-pane .pane__source")
      box.focus()
      const at = box.value.indexOf("save a file")
      box.setSelectionRange(at, at + "save a file".length)
    })()`);
    await page.type("save a page");
    const follows = await page.until(`document.querySelector("#live .editor .sequence").textContent.includes("save a page")`, 2000);
    await pause(1000);
    await page.press("Escape", "Escape", 27);
    const left = await page.until(`!document.querySelector(".edit-pane .pane__source") && !!document.activeElement.closest(".editor")`, 2000);
    report(
      "a click on the sequence opens its source in the panel, the drawing follows each key, and Escape gives the caret back",
      opened && follows && file("guide/11-live.md").includes("you -> dev  save a page") && left,
      `opened ${opened}, follows ${follows}, left ${left}`,
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
