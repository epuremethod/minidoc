// The croquis in a real Chrome: what the fixtures cannot show. The page
// hydrates with no mismatch and no error, shows the text the server drew,
// and turns editing on. Then the sync, on a folder of its own in the
// system's temporary folder: a key writes the file, a save on disk lands
// with the caret kept, both sides' changes stay, two pages follow each
// other, and a renamed heading renames the page. Chrome is driven through
// its DevTools protocol, on Node's own WebSocket. Run it by hand:
// `node test2/chrome.mjs [screenshot.png]`.
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { createServer, request } from "node:http";
import { crc32, deflateSync } from "node:zlib";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const core = fileURLToPath(new URL("../", import.meta.url));
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const results = [];
const report = (name, ok, detail = "") => {
  results.push(ok);
  console.log(`${ok ? "ok  " : "FAIL"} ${name}${detail ? `: ${detail}` : ""}`);
};

function chrome() {
  const found = [
    process.env.CHROME,
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    ...["google-chrome", "chromium"].map((name) => {
      const which = spawnSync("which", [name], { encoding: "utf8" });
      return which.status === 0 ? which.stdout.trim() : undefined;
    }),
  ].find((path) => path && existsSync(path));
  if (!found) {
    console.error("The check needs Chrome or Chromium, or CHROME set to its path.");
    process.exit(2);
  }
  return found;
}

// A croquis server on `folder`, on a port of its own, under a base as maia
// serves an app: `/serve/<project>/`, the prefix left on each request.
async function serve(folder) {
  const port = 19000 + Math.floor(Math.random() * 1000);
  const child = spawn(process.execPath, ["src2/cli.mjs", folder], {
    cwd: core,
    env: { ...process.env, PORT: String(port), MAIA_BASE: "/serve/croquis/" },
    stdio: ["ignore", "ignore", "inherit"],
  });
  const base = `http://localhost:${port}/serve/croquis/`;
  for (let i = 0; i < 100; i++) {
    if (await fetch(base).then((res) => res.ok, () => false)) break;
    await pause(100);
  }
  return { port, base, child };
}
const { port, base, child: server } = await serve("croquis");

// The folder of the sync's checks: two pages with one line in each block.
const folder = mkdtempSync(join(tmpdir(), "minidoc-sync-"));
const start = "# Check\n\nFirst paragraph.\n\nSecond paragraph.\n";
writeFileSync(join(folder, "a.md"), start);
writeFileSync(join(folder, "b.md"), "# Other\n");
const synced = await serve(folder);

/** A PNG of `width` × `height` grey pixels. */
function png(width, height) {
  const chunk = (type, data) => {
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(Buffer.concat([Buffer.from(type), data])));
    return Buffer.concat([length, Buffer.from(type), data, crc]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8; // 8 bits, grey
  const rows = Buffer.alloc((width + 1) * height, 0x80);
  for (let row = 0; row < height; row++) rows[row * (width + 1)] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(rows)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

// The folder of the images' checks: a page with an image line, and its image.
const pictures = mkdtempSync(join(tmpdir(), "minidoc-images-"));
mkdirSync(join(pictures, "images"));
writeFileSync(join(pictures, "images/cat.png"), png(1, 1));
writeFileSync(join(pictures, "a.md"), "# Pictures\n\n![a cat](images/cat.png)\n\nText.\n");
writeFileSync(join(pictures, "b.md"), "# Other\n");
const pictured = { ...(await serve(pictures)), folder: pictures };
const pictureOf = (name) => readFileSync(join(pictures, name), "utf8");

// The folder of the components' checks: a template with two parts, a
// component of its own, and a long page with headings and a callout.
const parted = mkdtempSync(join(tmpdir(), "minidoc-parts-"));
mkdirSync(join(parted, "components"));
writeFileSync(
  join(parted, "index.html"),
  '<!doctype html><html><head><title>t</title></head><body><nav></nav><aside data-component="contents"></aside><article></article><footer data-component="count"></footer></body></html>',
);
writeFileSync(join(parted, "components/count.jsx"), "export default function Count({ pages }) {\n  return <p>{pages.length} pages</p>;\n}\n");
const filler = Array.from({ length: 30 }, (_, i) => `Paragraph ${i + 1} of the filler.`).join("\n\n");
writeFileSync(
  join(parted, "a.md"),
  `# Parts\n\n::: note\n**A note**\nIts text.\n:::\n\n## A part\n\n${filler}\n\n## Far below\n\nThe end.\n`,
);
writeFileSync(join(parted, "b.md"), "# Other\n");
const parts = { ...(await serve(parted)), folder: parted };

const profile = mkdtempSync(join(tmpdir(), "minidoc-croquis-"));
const browser = spawn(chrome(), ["--headless=new", "--disable-gpu", "--remote-debugging-port=0", `--user-data-dir=${profile}`, "about:blank"], { stdio: "ignore" });
const active = join(profile, "DevToolsActivePort");
for (let i = 0; i < 100 && !existsSync(active); i++) await pause(100);
const [devPort, path] = readFileSync(active, "utf8").trim().split("\n");
const socket = new WebSocket(`ws://127.0.0.1:${devPort}${path}`);
await new Promise((resolve) => socket.addEventListener("open", resolve, { once: true }));
let id = 0;
const waiting = new Map();
const messages = [];
socket.addEventListener("message", ({ data }) => {
  const message = JSON.parse(data);
  if (message.id && waiting.has(message.id)) {
    const { resolve, reject } = waiting.get(message.id);
    waiting.delete(message.id);
    message.error ? reject(new Error(message.error.message)) : resolve(message.result);
  } else if (message.method) messages.push(message);
});
const send = (method, params = {}, sessionId) =>
  new Promise((resolve, reject) => {
    waiting.set(++id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params, ...(sessionId && { sessionId }) }));
  });
/** A tab, with its own session: `on` sends to it, `evaluate` runs in it. */
async function tab() {
  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
  const on = (method, params) => send(method, params, sessionId);
  await on("Page.enable");
  await on("Runtime.enable");
  await on("Emulation.setDeviceMetricsOverride", { width: 1200, height: 900, deviceScaleFactor: 1, mobile: false });
  const evaluate = async (expression) => {
    const { result, exceptionDetails } = await on("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
    return result.value;
  };
  return { on, evaluate, sessionId };
}
const { on, evaluate } = await tab();

/** The first block whose text starts with `start`. A landed block may take a new id, so a check finds blocks by their text. */
const blockOf = (start) =>
  `[...document.querySelectorAll("article [id^='block-']")].find((b) => b.textContent.startsWith(${JSON.stringify(start)}))`;

/** Put the caret in the block whose text starts with `start`, at an offset of its text or at its end, and focus the editor. */
const caret = (evaluate, start, offset) =>
  evaluate(`(() => {
    const el = ${blockOf(start)};
    el.closest("[contenteditable=true]").focus();
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    let node = null, left = ${offset ?? "Infinity"};
    while (walker.nextNode()) {
      const text = walker.currentNode;
      if (!text.data.replace(/\u200b/g, "").length) continue;
      node = text;
      if (left <= text.length) break;
      left -= text.length;
    }
    const range = document.createRange();
    range.setStart(node, Math.min(left, node.length));
    range.collapse(true);
    const selection = getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    return true;
  })()`);
/** The block the caret is in, and its offset there. */
const where = (evaluate) =>
  evaluate(`(() => {
    const selection = getSelection();
    const block = selection.anchorNode?.parentElement?.closest("[id^='block-']");
    return block ? block.id + ":" + selection.anchorOffset : "none";
  })()`);
const fileOf = (name) => readFileSync(join(folder, name), "utf8");
const waitFor = async (test, ms = 3000) => {
  for (let i = 0; i < ms / 100; i++) {
    if (await test()) return true;
    await pause(100);
  }
  return false;
};

try {
  // The text the server drew, before any script runs.
  const served = await fetch(base).then((res) => res.text());
  const blocks = (html) => [...html.matchAll(/id="block-[^"]+"[^>]*>([\s\S]*?)<\/(?:h\d|p|li|pre|div|tr)>/g)].length;

  await on("Page.navigate", { url: base });
  await pause(1500);

  const errors = messages
    .filter((m) => m.method === "Runtime.exceptionThrown" || (m.method === "Runtime.consoleAPICalled" && ["error", "warning"].includes(m.params.type)))
    .map((m) => m.params.exceptionDetails?.exception?.description ?? m.params.args?.map((a) => a.value ?? a.description).join(" "));
  report("the page hydrates with no error and no mismatch", errors.length === 0, errors.join(" | ").slice(0, 600));

  const editable = await evaluate(`document.querySelector("article .editor")?.getAttribute("contenteditable")`);
  report("editing turns on once the page has hydrated", editable === "true", `contenteditable=${editable}`);

  const shown = await evaluate(`[...document.querySelectorAll("article [id^='block-']")].length`);
  report("the page shows the blocks the server drew", shown === blocks(served) && shown > 0, `${shown} shown, ${blocks(served)} served`);

  const title = await evaluate("document.title");
  report("the title is the page's title", title === "A folder of markdown", title);

  const current = await evaluate(`document.querySelector("nav a[aria-current=page]")?.textContent`);
  report("the menu marks the current page", current === "A folder of markdown", current);

  const direct = await fetch(`http://localhost:${port}/`).then((res) => res.status);
  report("the server's own address, with no base, serves the page too", direct === 200, `status ${direct}`);

  // ── The sync ─────────────────────────────────────────────────────────
  const one = await tab();
  await one.on("Page.navigate", { url: `${synced.base}a.html` });
  await pause(1200);
  await one.evaluate("window.__kept = 1");

  const footer = await one.evaluate(`(() => {
    const footer = document.querySelector("body > footer");
    const article = document.querySelector("article");
    if (!footer) return "no footer";
    const links = [...footer.querySelectorAll("a")].map((a) => a.getAttribute("href") + " " + getComputedStyle(a, "::after").content + " " + a.textContent);
    const below = footer.getBoundingClientRect().top >= article.getBoundingClientRect().bottom;
    return links.join(", ") + (below ? ", below the article" : ", not below") + (footer.closest("[contenteditable]") ? ", editable" : "");
  })()`);
  report("the default template ends the page with a footer to the next page, below the article and not editable", footer === 'b.html " →" Other, below the article', footer);

  await caret(one.evaluate, "First paragraph");
  await one.on("Input.insertText", { text: " typed" });
  const written = await waitFor(() => fileOf("a.md") === start.replace("First paragraph.", "First paragraph. typed"));
  report("a key in the page writes the file, and the other blocks keep their bytes", written, JSON.stringify(fileOf("a.md")));

  await caret(one.evaluate, "Second paragraph", 3);
  const before = await where(one.evaluate);
  writeFileSync(join(folder, "a.md"), fileOf("a.md").replace("# Check", "# Check from disk"));
  const landed = await waitFor(async () => (await one.evaluate(`${blockOf("Check")}?.textContent`)) === "Check from disk");
  const after = await where(one.evaluate);
  const kept = await one.evaluate("window.__kept === 1");
  report("a save on disk lands in the page with no reload, and the caret stays", landed && kept && before === after, `${before} → ${after}, reloaded: ${!kept}`);

  await caret(one.evaluate, "Second paragraph");
  await one.on("Input.insertText", { text: " here" });
  writeFileSync(join(folder, "a.md"), fileOf("a.md").replace("First paragraph. typed", "First paragraph. typed, and disk"));
  const both = await waitFor(() => {
    const text = fileOf("a.md");
    return text.includes("First paragraph. typed, and disk") && text.includes("Second paragraph. here");
  });
  const texts = await one.evaluate(`[...document.querySelectorAll("article [id^='block-']")].map((b) => b.textContent).join(" | ")`);
  report("a word typed in one block and a change on disk to another both stay", both && texts.includes("and disk") && texts.includes("paragraph. here"), `${JSON.stringify(fileOf("a.md"))} / ${texts}`);

  const two = await tab();
  await two.on("Page.navigate", { url: `${synced.base}a.html` });
  await pause(1200);
  await caret(one.evaluate, "First paragraph");
  await one.on("Input.insertText", { text: " shared" });
  const followed = await waitFor(async () => (await two.evaluate(`${blockOf("First paragraph")}?.textContent ?? ""`)).endsWith(" shared"));
  report("a key in one page shows in another page of the same file", followed);

  await caret(one.evaluate, "Check");
  await one.on("Input.insertText", { text: " renamed" });
  const renamed = await waitFor(async () =>
    (await two.evaluate(`document.querySelector("nav a[aria-current=page]").textContent + " / " + document.title`)) ===
    "Check from disk renamed / Check from disk renamed",
  );
  report("a renamed heading changes the menu and the title", renamed, await two.evaluate(`document.querySelector("nav a[aria-current=page]").textContent + " / " + document.title`));

  // ── The template ─────────────────────────────────────────────────────
  await caret(one.evaluate, "Second paragraph");
  await one.on("Input.insertText", { text: " before" });
  writeFileSync(
    join(folder, "index.html"),
    "<!doctype html><html><head><title>t</title></head><body><header>New template</header><nav></nav><article></article></body></html>",
  );
  const reloaded = await waitFor(async () =>
    (await one.evaluate(`document.querySelector("header")?.textContent ?? ""`).catch(() => "")) === "New template",
  5000);
  const saved = fileOf("a.md").includes("Second paragraph. here before");
  report("a change of index.html reloads the page in the new template, once its edits are saved", reloaded && saved, JSON.stringify(fileOf("a.md")));

  // ── Images ───────────────────────────────────────────────────────────
  const pics = await tab();
  await pics.on("Page.navigate", { url: `${pictured.base}a.html` });
  await pause(1500);
  const shownImage = (start) =>
    pics.evaluate(`(() => {
      const img = [...document.querySelectorAll("article img")].find((i) => i.getAttribute("src").startsWith(${JSON.stringify(start)}));
      return img ? img.getAttribute("src") + " " + img.naturalWidth + "x" + img.naturalHeight + " " + img.complete : "none";
    })()`);
  const servedPage = await fetch(`${pictured.base}a.html`).then((res) => res.text());
  await waitFor(async () => / 1x1 true$/.test(await shownImage("images/cat.png")));
  const catShown = await shownImage("images/cat.png");
  report("an image line shows the image, served and hydrated", servedPage.includes('src="images/cat.png') && / 1x1 true$/.test(catShown), catShown);

  // A paste of a 2×2 image at the end of the text: a `paste` event that holds a file.
  await caret(pics.evaluate, "Text");
  await pics.evaluate(`(() => {
    const bytes = Uint8Array.from(atob(${JSON.stringify(png(2, 2).toString("base64"))}), (c) => c.charCodeAt(0));
    const transfer = new DataTransfer();
    transfer.items.add(new File([bytes], "image.png", { type: "image/png" }));
    const target = getSelection().anchorNode.parentElement;
    target.dispatchEvent(new ClipboardEvent("paste", { clipboardData: transfer, bubbles: true, cancelable: true }));
    return true;
  })()`);
  const atOnce = await shownImage("blob:");
  const stored = await waitFor(() => existsSync(join(pictured.folder, "images/a-1.png")) && pictureOf("a.md").includes("![](images/a-1.png)"));
  const paneFocus = await pics.evaluate(`(() => {
    const pane = document.querySelector(".picture-pane");
    return pane ? (pane.querySelector("input") === document.activeElement ? "text field" : "elsewhere: " + document.activeElement?.tagName) : "no pane";
  })()`);
  await pics.on("Input.insertText", { text: "two dots" });
  const described = await waitFor(() => pictureOf("a.md").includes("![two dots](images/a-1.png)"));
  report(
    "a pasted image shows at once, is written to images/a-1.png, its pane opens on the text, and the text is written",
    atOnce !== "none" && stored && paneFocus === "text field" && described,
    `at once: ${atOnce}; stored: ${stored}; pane: ${paneFocus}; ${JSON.stringify(pictureOf("a.md"))}`,
  );

  // A rename in the pane, with another page that links the image.
  writeFileSync(join(pictured.folder, "b.md"), "# Other\n\n![a copy](images/a-1.png)\n");
  await pause(500);
  await pics.evaluate(`(() => {
    const input = document.querySelectorAll(".picture-pane input")[1];
    input.focus();
    input.select();
    return true;
  })()`);
  await pics.on("Input.insertText", { text: "images/diagram.png" });
  await pics.on("Input.dispatchKeyEvent", { type: "keyDown", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 });
  await pics.on("Input.dispatchKeyEvent", { type: "keyUp", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 });
  const moved = await waitFor(
    () =>
      existsSync(join(pictured.folder, "images/diagram.png")) &&
      !existsSync(join(pictured.folder, "images/a-1.png")) &&
      pictureOf("a.md").includes("![two dots](images/diagram.png)") &&
      pictureOf("b.md").includes("![a copy](images/diagram.png)"),
  );
  const stillShown = await waitFor(async () => / 2x2 true$/.test(await shownImage("images/diagram.png")));
  report(
    "a rename in the pane moves the file, rewrites another page that links it, and the image still shows",
    moved && stillShown,
    `${await shownImage("images/diagram.png")}; a: ${JSON.stringify(pictureOf("a.md"))}; b: ${JSON.stringify(pictureOf("b.md"))}`,
  );

  // An image changed on disk: 3×1 in place of 2×2.
  writeFileSync(join(pictured.folder, "images/diagram.png"), png(3, 1));
  const redrawn = await waitFor(async () => / 3x1 true$/.test(await shownImage("images/diagram.png")));
  report("an image changed on disk is drawn again", redrawn, await shownImage("images/diagram.png"));

  // ── Components ───────────────────────────────────────────────────────
  const from = messages.length;
  const comp = await tab();
  await comp.on("Page.navigate", { url: `${parts.base}a.html` });
  await pause(1500);
  const partErrors = messages
    .slice(from)
    .filter((m) => m.method === "Runtime.exceptionThrown" || (m.method === "Runtime.consoleAPICalled" && ["error", "warning"].includes(m.params.type)))
    .map((m) => m.params.exceptionDetails?.exception?.description ?? m.params.args?.map((a) => a.value ?? a.description).join(" "));
  const contentsText = () => comp.evaluate(`[...document.querySelectorAll("aside a")].map((a) => a.getAttribute("href") + " " + a.textContent).join(" | ")`);
  const countText = () => comp.evaluate(`document.querySelector("footer")?.textContent ?? ""`);
  const firstContents = await contentsText();
  const firstCount = await countText();
  report(
    "the contents and a component of the folder show, hydrated with no error",
    partErrors.length === 0 && firstContents === "#a-part A part | #far-below Far below" && firstCount === "2 pages",
    `${firstContents}; ${firstCount}; ${partErrors.join(" | ").slice(0, 400)}`,
  );

  await caret(comp.evaluate, "Far below");
  await comp.on("Input.insertText", { text: " and beyond" });
  const followsKeys = await waitFor(async () => (await contentsText()).includes("#far-below-and-beyond Far below and beyond"));
  await comp.evaluate(`window.scrollTo(0, 0); document.activeElement.blur(); true`);
  await comp.evaluate(`document.querySelector('aside a[href="#far-below-and-beyond"]').click(); true`);
  const led = await waitFor(async () =>
    comp.evaluate(`(() => {
      const heading = [...document.querySelectorAll("article h2")].find((h) => h.textContent.startsWith("Far below"));
      const box = heading.getBoundingClientRect();
      return location.hash === "#far-below-and-beyond" && scrollY > 0 && box.top >= 0 && box.bottom <= innerHeight;
    })()`),
  );
  const where_ = await comp.evaluate(`location.hash + " scrollY " + scrollY`);
  report("a heading typed in the page shows in the contents at once, and a click on its link leads to it", followsKeys && led, `${await contentsText()}; ${where_}`);

  await caret(comp.evaluate, "A note");
  const opened = await waitFor(async () => (await comp.evaluate(`document.querySelector("article .callout__byline").getBoundingClientRect().height`)) > 5);
  await caret(comp.evaluate, "The end");
  const closed = await waitFor(async () => (await comp.evaluate(`document.querySelector("article .callout__byline").getBoundingClientRect().height`)) === 0);
  report("an empty byline takes a line only while the caret is in its callout", opened && closed, `opened ${opened}, closed ${closed}`);

  writeFileSync(join(parted, "c.md"), "# Third\n");
  const counted = await waitFor(async () => (await countText()) === "3 pages");
  report("a new file on disk changes a component of the folder", counted, await countText());

  writeFileSync(join(parted, "components/count.jsx"), "export default function Count({ pages }) {\n  return <p>Pages: {pages.length}</p>;\n}\n");
  const rebuilt = await waitFor(async () => (await countText().catch(() => "")) === "Pages: 3", 6000);
  report("a change of a component's file reloads the page with the new component", rebuilt, await countText().catch(() => "reloading"));

  // A proxy that passes the pages but refuses the socket, as a proxy that
  // does not pass upgrades: the page must not reload without end.
  const refusing = createServer((req, res) => {
    const forward = request({ port: parts.port, path: req.url, method: req.method, headers: req.headers }, (answer) => {
      res.writeHead(answer.statusCode, answer.headers);
      answer.pipe(res);
    });
    req.pipe(forward);
  });
  refusing.on("upgrade", (_req, upgrade) => upgrade.destroy());
  await new Promise((done) => refusing.listen(0, "127.0.0.1", done));
  const off = await tab();
  await off.on("Page.navigate", { url: `http://127.0.0.1:${refusing.address().port}/serve/croquis/a.html` });
  await pause(5000);
  const loads = messages.filter((message) => message.sessionId === off.sessionId && message.method === "Page.loadEventFired").length;
  const banner = await off.evaluate(`document.body.innerText.includes("The sync is off")`).catch(() => false);
  report("a socket that never opens does not reload the page, and the page says the sync is off", loads <= 1 && banner, `${loads} loads in 5 s, banner ${banner}`);
  refusing.close();

  // With a path, a screenshot of the page in light and one in dark.
  const shot = process.argv[2];
  if (shot) {
    for (const scheme of ["light", "dark"]) {
      await on("Emulation.setEmulatedMedia", { features: [{ name: "prefers-color-scheme", value: scheme }] });
      await pause(200);
      const { data } = await on("Page.captureScreenshot", { format: "png", captureBeyondViewport: true });
      writeFileSync(shot.replace(/\.png$/, `-${scheme}.png`), Buffer.from(data, "base64"));
    }
  }
} finally {
  socket.close();
  browser.kill();
  server.kill();
  synced.child.kill();
  pictured.child.kill();
  parts.child.kill();
}
process.exit(results.every(Boolean) ? 0 : 1);
