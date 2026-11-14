// The dev runner against a real filesystem and a real socket — the two things
// the YAML fixtures cannot stand in for.

import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import net from "node:net";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";
import { dev, nodeFs, run, watch } from "../src/Minidoc.mjs";

const here = path.dirname(new URL(import.meta.url).pathname);

const config = [
  "# a tiny site",
  "var:",
  "  site: Marmot Docs # the name",
  "  home:",
  "    file: content/home.md",
  "    transform: shout",
  "build:",
  "  - output: dist/index.html",
  "    input: |-",
  "      <html><body><h1>{{site}}</h1>{{home}}</body></html>",
  "",
].join("\n");

const shout = (word) => `export function shout(text) {\n  return "<p>${word}: " + text.trim() + "</p>";\n}\n`;

const build = [
  `import { nodeFs, run } from "${path.join(here, "..", "src", "Minidoc.mjs")}";`,
  'import { shout } from "./shout.mjs";',
  "",
  "await run({",
  '  fs: nodeFs(new URL("../", import.meta.url).pathname),',
  '  glob: "config.yaml",',
  "  transform: { shout },",
  "});",
  "",
].join("\n");

/** A site on disk: config, one content file, one transformer, one build script. */
async function site() {
  const root = await mkdtemp(path.join(os.tmpdir(), "minidoc-dev-"));
  await mkdir(path.join(root, "content"));
  await mkdir(path.join(root, "src"));
  await writeFile(path.join(root, "config.yaml"), config);
  await writeFile(path.join(root, "content", "home.md"), "Hello **watchers**.\n");
  await writeFile(path.join(root, "src", "shout.mjs"), shout("ONE"));
  await writeFile(path.join(root, "src", "build.mjs"), build);
  return root;
}

const options = (root) => ({
  glob: "config.yaml",
  build: "src/build.mjs",
  root,
  fs: nodeFs(root),
});

/** The served page, once it says `want` — or once we give up waiting. */
async function until(server, want, ms = 15000) {
  const limit = Date.now() + ms;
  const get = async () => (await fetch(`http://127.0.0.1:${server.port}/`)).text();
  for (let page = await get(); ; page = await get()) {
    if (page.includes(want) || Date.now() > limit) return page;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
}

const port = (text) => Number(/port: (\d+)/.exec(text)?.[1]);

/** What a reload stream says, up to and including `want` — or until we give up. */
async function hear(reader, want, ms = 15000) {
  const limit = Date.now() + ms;
  let said = "";
  while (!said.includes(want) && Date.now() < limit) {
    const { value, done } = await reader.read();
    if (done) break;
    said += new TextDecoder().decode(value);
  }
  return said;
}

/** A page reading or writing a markdown file through the server, as the editor does. */
const file = (server, at, { write, headers = { "x-minidoc-edit": "1" } } = {}) =>
  fetch(`http://127.0.0.1:${server.port}/__minidoc/file?path=${encodeURIComponent(at)}`, {
    method: write ? "PUT" : "GET",
    headers,
    ...(write && { body: JSON.stringify(write) }),
  });

/** The reload stream, opened by the page named `page`. */
async function stream(server, page) {
  const res = await fetch(`http://127.0.0.1:${server.port}/__minidoc?page=${page}`);
  return res.body.getReader();
}

/** A request `fetch` would not send, path untouched. */
const raw = (at, target) =>
  new Promise((resolve) => {
    const socket = net.connect(at, "127.0.0.1", () =>
      socket.write(`GET ${target} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n`),
    );
    let said = "";
    socket.on("data", (chunk) => (said += chunk));
    socket.on("end", () => resolve(said));
  });

/** A write sent with the `Host` and `Origin` a browser sends from a page at `host`; `fetch` cannot name the host. */
const hosted = (server, host, origin, write) =>
  new Promise((resolve) => {
    const body = JSON.stringify(write);
    const socket = net.connect(server.port, "127.0.0.1", () =>
      socket.write(
        `PUT /__minidoc/file?path=content%2Fhome.md HTTP/1.1\r\nHost: ${host}\r\nOrigin: ${origin}\r\n` +
          `x-minidoc-edit: 1\r\ncontent-type: application/json\r\ncontent-length: ${Buffer.byteLength(body)}\r\nConnection: close\r\n\r\n${body}`,
      ),
    );
    let said = "";
    socket.on("data", (chunk) => (said += chunk));
    socket.on("end", () => resolve(Number(said.slice(9, 12))));
  });

/**
 * A window and `EventSource` for the injected script. Hiding and showing fire
 * what a browser fires when a tab goes to the back or the page enters the
 * back and forward cache, and the reverse.
 */
function standIn() {
  const streams = [];
  const listeners = {};
  const on = (target) => (type, listener) => (target[type] ??= []).push(listener);
  const fire = (target, type, event = { type }) => (target[type] ?? []).forEach((l) => l(event));

  class EventSource {
    constructor(url) {
      this.url = url;
      this.closed = false;
      this.listeners = {};
      this.addEventListener = on(this.listeners);
      streams.push(this);
    }
    close() {
      this.closed = true;
    }
    say(data) {
      if (this.closed) return;
      const event = { type: "message", data };
      this.onmessage?.(event);
      fire(this.listeners, "message", event);
    }
    fail(data) {
      if (this.closed) return;
      fire(this.listeners, "failed", { type: "failed", data });
    }
  }

  const elements = {};
  const document = { visibilityState: "visible", hidden: false, listeners: {} };
  document.addEventListener = on(document.listeners);
  document.getElementById = (id) => elements[id] ?? null;
  document.createElement = (tag) => ({
    tag,
    style: {},
    textContent: "",
    children: [],
    append(...children) {
      this.children.push(...children);
    },
    remove() {
      delete elements[this.id];
    },
  });
  document.body = {
    appendChild(element) {
      elements[element.id] = element;
      return element;
    },
  };
  const browser = {
    streams,
    reloads: 0,
    banner: () => elements.__minidoc,
    /** The failure the banner shows, or undefined when there is none. */
    shown: () => elements.__minidoc?.children.find((c) => c.tag === "pre").textContent,
    close: () => elements.__minidoc.children.find((c) => c.tag === "button").onclick(),
    hide() {
      Object.assign(document, { visibilityState: "hidden", hidden: true });
      fire(document.listeners, "visibilitychange");
      fire(listeners, "pagehide", { type: "pagehide", persisted: true });
    },
    show() {
      fire(listeners, "pageshow", { type: "pageshow", persisted: true });
      Object.assign(document, { visibilityState: "visible", hidden: false });
      fire(document.listeners, "visibilitychange");
    },
  };
  const window = {
    EventSource,
    document,
    location: { reload: () => browser.reloads++ },
    addEventListener: on(listeners),
  };
  window.window = window;
  browser.window = window;
  return browser;
}

test("dev serves the output and rebuilds what changed", async (t) => {
  const root = await site();
  const server = await dev({ ...options(root), edit: ["content"] });
  t.after(async () => {
    server.stop();
    await rm(root, { recursive: true, force: true });
  });

  const written = await readFile(path.join(root, "config.yaml"), "utf8");
  await t.test("draws a port and writes it to the entry config", () => {
    assert.equal(port(written), server.port);
    assert.match(written, /# a tiny site/);
    assert.match(written, /# the name/);
  });

  await t.test("serves the page with the reload stream injected", async () => {
    const page = await (await fetch(`http://127.0.0.1:${server.port}/`)).text();
    assert.match(page, /<h1>Marmot Docs<\/h1>/);
    assert.match(page, /<p>ONE: Hello \*\*watchers\*\*\.<\/p>/);
    assert.match(page, /EventSource\("\/__minidoc\?page="\+page\)/);
    // injected where the page ends, not appended past it
    assert.ok(page.endsWith("</script></body></html>"));
  });

  await t.test("closes the reload stream while the page is hidden", async () => {
    const page = await (await fetch(`http://127.0.0.1:${server.port}/`)).text();
    const browser = standIn();
    vm.runInNewContext(/<script>(.*)<\/script><\/body>/s.exec(page)[1], browser.window);
    assert.equal(browser.streams.length, 1);
    assert.match(browser.streams[0].url, /^\/__minidoc\?page=\w+$/, "the stream names its page");

    browser.hide();
    assert.ok(browser.streams[0].closed);

    browser.show();
    assert.equal(browser.streams.length, 2);
    assert.equal(browser.streams[1].url, browser.streams[0].url, "the same page, by the same name");
    assert.ok(!browser.streams[1].closed);

    browser.streams[1].say("reload");
    assert.equal(browser.reloads, 1);
  });

  await t.test("behind a proxy, the page reaches the server under the prefix the proxy names", async () => {
    const asked = { headers: { "x-forwarded-prefix": "/docs/muse" } };
    const page = await (await fetch(`http://127.0.0.1:${server.port}/`, asked)).text();
    const browser = standIn();
    vm.runInNewContext(/<script>(.*)<\/script><\/body>/s.exec(page)[1], browser.window);
    assert.match(browser.streams[0].url, /^\/docs\/muse\/__minidoc\?page=\w+$/);
    assert.equal(browser.window.__minidocBase, "/docs/muse", "the editor writes under it too");
  });

  await t.test("a prefix that is not a plain path is ignored", async () => {
    const asked = { headers: { "x-forwarded-prefix": '/x"</script><script>alert(1)' } };
    const page = await (await fetch(`http://127.0.0.1:${server.port}/`, asked)).text();
    assert.doesNotMatch(page, /alert/);
    const browser = standIn();
    vm.runInNewContext(/<script>(.*)<\/script><\/body>/s.exec(page)[1], browser.window);
    assert.match(browser.streams[0].url, /^\/__minidoc\?page=\w+$/);
    assert.equal(browser.window.__minidocBase, "");
  });

  await t.test("tells every page to reload when a build lands, except the page whose own write made it", async () => {
    const writer = await stream(server, "writer");
    const other = await stream(server, "other");
    const base = await (await file(server, "content/home.md")).text();
    const wrote = await file(server, "content/home.md", { write: { text: "Hello *page*.\n", base, page: "writer" } });
    assert.equal(wrote.status, 200);
    assert.match(await hear(other, "data: reload"), /data: reload/);
    const heard = await hear(writer, "event: built");
    assert.match(heard, /event: built/, "the page that wrote is told the build landed");
    assert.doesNotMatch(heard, /data: reload/, "and keeps its caret");
    assert.match(await until(server, "Hello *page*."), /Hello \*page\*\./);

    // Another program's save reloads every page, the writer too.
    await writeFile(path.join(root, "content", "home.md"), "Hello *again*.\n");
    assert.match(await hear(writer, "data: reload"), /data: reload/);
    assert.match(await hear(other, "data: reload"), /data: reload/);
    await writer.cancel();
    await other.cancel();
    assert.match(await until(server, "Hello *again*."), /Hello \*again\*\./);
  });

  await t.test("a page writes a markdown file in a folder `edit` names, and the site rebuilds", async () => {
    const read = await file(server, "content/home.md");
    assert.equal(read.status, 200);
    const base = await read.text();
    assert.equal(base, "Hello *again*.\n");
    const wrote = await file(server, "content/home.md", { write: { text: "Hello **edited**.\n", base, page: "p" } });
    assert.equal(wrote.status, 200);
    assert.equal(await readFile(path.join(root, "content", "home.md"), "utf8"), "Hello **edited**.\n");
    assert.match(await until(server, "Hello **edited**."), /Hello \*\*edited\*\*\./);
  });

  await t.test("a write over a file that changed since the page read it is refused, and the file stays", async () => {
    const base = await (await file(server, "content/home.md")).text();
    await writeFile(path.join(root, "content", "home.md"), "Hello *elsewhere*.\n");
    const wrote = await file(server, "content/home.md", { write: { text: "Hello *mine*.\n", base, page: "p" } });
    assert.equal(wrote.status, 409);
    assert.equal(await wrote.text(), "Hello *elsewhere*.\n", "the refusal holds the file as it is");
    assert.equal(await readFile(path.join(root, "content", "home.md"), "utf8"), "Hello *elsewhere*.\n");
    await until(server, "Hello *elsewhere*.");
  });

  // A build broken by a thrown transformer, seen through one stream kept
  // open across the next four tests.
  const get = async (p = "/") => (await fetch(`http://127.0.0.1:${server.port}${p}`)).text();
  const broken = { page: "", reader: null };

  await t.test("a failed build keeps the page and reloads nothing", async () => {
    broken.page = await get();
    const stream = await fetch(`http://127.0.0.1:${server.port}/__minidoc`);
    broken.reader = stream.body.getReader();

    await writeFile(path.join(root, "src", "shout.mjs"), 'export function shout() {\n  throw new Error("shout is broken");\n}\n');
    const said = await hear(broken.reader, "event: failed");
    assert.doesNotMatch(said, /data: reload/);
    const message = JSON.parse(/^data: (.*)$/m.exec(said.slice(said.indexOf("event: failed")))[1]);
    assert.equal(message, "dist/index.html: shout is broken in file content/home.md", "one line, led by the output");
    assert.equal(await get(), broken.page, "the page served before is still served");
  });

  await t.test("a page opened while the build is broken is told at once", async () => {
    const late = await fetch(`http://127.0.0.1:${server.port}/__minidoc`);
    const reader = late.body.getReader();
    assert.match(await hear(reader, "event: failed", 2000), /shout is broken/);
    await reader.cancel();
  });

  await t.test("the injected script shows the failure on the page", async () => {
    const browser = standIn();
    vm.runInNewContext(/<script>(.*)<\/script><\/body>/s.exec(broken.page)[1], browser.window);
    browser.streams[0].fail(JSON.stringify("Error: shout is broken\n    at shout"));
    assert.equal(browser.shown(), "Error: shout is broken\n    at shout");
    assert.equal(browser.reloads, 0);
    browser.streams[0].fail(JSON.stringify("still broken"));
    assert.equal(browser.shown(), "still broken", "one banner, the latest failure");
  });

  await t.test("the failure on the page can be closed, and the next one shows", () => {
    const browser = standIn();
    vm.runInNewContext(/<script>(.*)<\/script><\/body>/s.exec(broken.page)[1], browser.window);
    browser.streams[0].fail(JSON.stringify("broken"));
    browser.close();
    assert.equal(browser.banner(), undefined);
    browser.streams[0].fail(JSON.stringify("broken again"));
    assert.equal(browser.shown(), "broken again");
  });

  await t.test("a bug in a transform keeps its stack", async () => {
    await writeFile(path.join(root, "src", "shout.mjs"), 'export function shout(text) {\n  return text.nope.trim();\n}\n');
    const said = await hear(broken.reader, "TypeError");
    assert.match(said, /TypeError: dist\/index.html: Cannot read properties of undefined/);
    assert.match(said, /\\n    at shout/, "the stack is printed");
  });

  await t.test("the next build that lands reloads the page", async () => {
    await writeFile(path.join(root, "src", "shout.mjs"), shout("ONE"));
    assert.match(await hear(broken.reader, "data: reload"), /data: reload/);
    await broken.reader.cancel();
  });

  await t.test("an edited transformer takes effect — the build is a fresh process", async () => {
    await writeFile(path.join(root, "src", "shout.mjs"), shout("TWO"));
    assert.match(await until(server, "TWO:"), /<p>TWO: /);
  });

  await t.test("rebuilds on a config change", async () => {
    await writeFile(path.join(root, "config.yaml"), written.replace("Marmot Docs", "Marmot Guide"));
    assert.match(await until(server, "Marmot Guide"), /<h1>Marmot Guide<\/h1>/);
  });

  await t.test("answers the paths a static host answers", async () => {
    const at = async (p) => await fetch(`http://127.0.0.1:${server.port}${p}`);
    assert.equal((await at("/index.html")).status, 200);
    assert.equal((await at("/nope.html")).status, 404);
    // `fetch` resolves `..` before it asks, so the way out is asked for raw.
    assert.match(await raw(server.port, "/../src/build.mjs"), /^HTTP\/1\.1 403/);
  });
});

test("the port is remembered, and never replaced", async (t) => {
  const root = await site();
  t.after(() => rm(root, { recursive: true, force: true }));
  const config = () => readFile(path.join(root, "config.yaml"), "utf8");

  const first = await dev(options(root));
  const drawn = first.port;
  first.stop();

  const again = await dev(options(root));
  assert.equal(again.port, drawn, "the same site keeps the same address");

  await t.test("points at a dev server already running on it", async () => {
    const before = await config();
    const twin = await dev(options(root));
    assert.equal(twin.port, drawn);
    assert.equal(await config(), before);
    twin.stop();
  });
  again.stop();

  await t.test("fails loud when something else took it", async (t) => {
    const squatter = net.createServer();
    await new Promise((resolve) => squatter.listen(drawn, "127.0.0.1", resolve));
    t.after(() => squatter.close());
    const before = await config();
    await assert.rejects(dev(options(root)), new RegExp(`port ${drawn} is taken`));
    assert.equal(port(await config()), drawn);
    assert.equal(await config(), before);
  });
});

test("an explicit port is the caller's, and is never written down", async (t) => {
  const root = await site();
  const before = await readFile(path.join(root, "config.yaml"), "utf8");
  const server = await dev({ ...options(root), port: 45999 });
  t.after(async () => {
    server.stop();
    await rm(root, { recursive: true, force: true });
  });
  assert.equal(server.port, 45999);
  assert.equal(await readFile(path.join(root, "config.yaml"), "utf8"), before);
});

test("watch builds and rebuilds without a server", async (t) => {
  const root = await site();
  const watcher = await watch({ glob: "config.yaml", build: "src/build.mjs", root });
  t.after(async () => {
    watcher.stop();
    await rm(root, { recursive: true, force: true });
  });

  const page = path.join(root, "dist", "index.html");
  assert.match(await readFile(page, "utf8"), /<p>ONE: /);

  await writeFile(path.join(root, "src", "shout.mjs"), shout("TWO"));
  const limit = Date.now() + 15000;
  let out = "";
  while (!out.includes("TWO:") && Date.now() < limit) {
    out = await readFile(page, "utf8");
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  assert.match(out, /<p>TWO: /);
});

test("watches content that lives outside the project", async (t) => {
  const root = await site();
  const shared = await mkdtemp(path.join(os.tmpdir(), "minidoc-shared-"));
  const note = path.join(shared, "note.md");
  await writeFile(note, "First note.\n");
  await writeFile(
    path.join(root, "config.yaml"),
    config.replace("    file: content/home.md", `    file: ${note}`),
  );
  // Content outside the root is read only when the build allows its folder.
  await writeFile(
    path.join(root, "src", "build.mjs"),
    build.replace("new URL(\"../\", import.meta.url).pathname)", `new URL("../", import.meta.url).pathname, { allow: [${JSON.stringify(shared)}] })`),
  );

  const server = await dev({ ...options(root), watch: [shared] });
  t.after(async () => {
    server.stop();
    await rm(root, { recursive: true, force: true });
    await rm(shared, { recursive: true, force: true });
  });

  assert.match(await until(server, "First note."), /First note\./);
  await writeFile(note, "Second note.\n");
  assert.match(await until(server, "Second note."), /Second note\./);
});

test("concurrent copies into one directory do not race", async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), "minidoc-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(path.join(root, "assets", "fonts"), { recursive: true });
  for (let i = 0; i < 20; i++) await writeFile(path.join(root, "assets", "fonts", `f${i}.woff2`), "x");

  const fs = nodeFs(root);
  await Promise.all([1, 2, 3].map(() => fs.copy("assets/fonts", "dist/fonts")));
  assert.equal(await readFile(path.join(root, "dist", "fonts", "f19.woff2"), "utf8"), "x");
});

test("copies reaching one directory by different paths do not race", async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), "minidoc-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(path.join(root, "assets", "fonts"), { recursive: true });
  for (let i = 0; i < 20; i++) await writeFile(path.join(root, "assets", "fonts", `f${i}.woff2`), "x");

  const fs = nodeFs(root);
  const outputs = ["content/a/../../dist/fonts", "content/b/../../dist/fonts", "./dist/fonts"];
  await Promise.all(outputs.map((output) => fs.copy("assets/fonts", output)));
  assert.equal(await readFile(path.join(root, "dist", "fonts", "f19.woff2"), "utf8"), "x");
});

test("two builds copying into one output do not race", async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), "minidoc-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(path.join(root, "assets", "fonts"), { recursive: true });
  for (let i = 0; i < 20; i++) await writeFile(path.join(root, "assets", "fonts", `f${i}.woff2`), "x");

  // One filesystem each, as a check run beside the dev server has.
  const builds = [1, 2, 3].map(() => nodeFs(root));
  await Promise.all(builds.map((fs) => fs.copy("assets/fonts", "dist/fonts")));
  assert.equal(await readFile(path.join(root, "dist", "fonts", "f19.woff2"), "utf8"), "x");
});

test("the filesystem never reaches outside its root unless allowed", async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), "minidoc-"));
  const outside = await mkdtemp(path.join(os.tmpdir(), "minidoc-outside-"));
  t.after(async () => {
    await rm(root, { recursive: true, force: true });
    await rm(outside, { recursive: true, force: true });
  });
  await writeFile(path.join(outside, "secret.txt"), "secret");
  const escape = path.relative(root, path.join(outside, "secret.txt"));

  const fs = nodeFs(root);
  await assert.rejects(fs.readFile(escape), /Path outside the project root/);
  await assert.rejects(fs.readFile(path.join(outside, "secret.txt")), /Path outside the project root/);
  await assert.rejects(fs.exists("content/../../x"), /Path outside the project root/);
  await assert.rejects(fs.writeFile("../evil.txt", "x"), /Path outside the project root/);
  await assert.rejects(fs.copy(escape, "dist/secret.txt"), /Path outside the project root/);
  await assert.rejects(fs.listFiles(outside), /Path outside the project root/);
  await fs.writeFile(path.join(root, "dist", "ok.txt"), "ok");
  assert.equal(await fs.readFile("content/../dist/ok.txt"), "ok");

  const allowed = nodeFs(root, { allow: [outside] });
  assert.equal(await allowed.readFile(escape), "secret");
  await assert.rejects(allowed.readFile(path.join(outside, "..", "elsewhere.txt")), /Path outside the project root/);

  await t.test("a page writes only the markdown of the folders `edit` names", async (t) => {
    const at = await site();
    await writeFile(path.join(at, "notes.md"), "not in content\n");
    await writeFile(path.join(at, "content", "data.yaml"), "a: 1\n");
    const server = await dev({ ...options(at), edit: ["content"] });
    const plain = await dev({ ...options(at), port: 45998 });
    t.after(async () => {
      server.stop();
      plain.stop();
      await rm(at, { recursive: true, force: true });
    });
    const base = "Hello **watchers**.\n";
    const write = (where, more = {}) => file(server, where, { write: { text: "x\n", base, page: "p" }, ...more });
    assert.equal((await write("notes.md")).status, 403, "outside the folders");
    assert.equal((await write(escape)).status, 403, "outside the root");
    assert.equal((await write("content/../notes.md")).status, 403, "out by a detour");
    assert.equal((await write("content/new.md")).status, 403, "a new file");
    assert.equal((await write("content/data.yaml")).status, 403, "not markdown");
    assert.equal((await write("content/home.md", { headers: {} })).status, 403, "without the editor's header");
    const foreign = { "x-minidoc-edit": "1", origin: "http://evil.example" };
    assert.equal((await write("content/home.md", { headers: foreign })).status, 403, "from another site");
    assert.equal((await file(plain, "content/home.md", { write: { text: "x\n", base, page: "p" } })).status, 404, "without `edit`, no write");
    assert.equal(await readFile(path.join(at, "content", "home.md"), "utf8"), base);
    assert.equal(await readFile(path.join(at, "notes.md"), "utf8"), "not in content\n");
  });

  await t.test("a page of the server on a local name writes, and a page on any other name cannot", async (t) => {
    const at = await site();
    const server = await dev({ ...options(at), edit: ["content"] });
    t.after(async () => {
      server.stop();
      await rm(at, { recursive: true, force: true });
    });
    const port = server.port;
    const home = path.join(at, "content", "home.md");
    let base = await readFile(home, "utf8");
    const from = async (host, origin = `http://${host}`) => {
      const text = `${base}${host}\n`;
      const status = await hosted(server, host, origin, { text, base, page: "p" });
      if (status === 200) base = text;
      return status;
    };
    for (const name of ["a.local", "docs.localhost", "localhost", "127.0.0.1", "[::1]"]) {
      assert.equal(await from(`${name}:${port}`), 200, name);
    }
    assert.equal(await from(`evil.example:${port}`), 403, "a name public DNS gives, which a rebinding could point here");
    assert.equal(await from(`a.local.evil.example:${port}`), 403, "a public name that holds `.local`");
    assert.equal(await from(`a.local:${port}`, `http://b.local:${port}`), 403, "a page of another origin");
    assert.equal(await from(`a.local:${port}`, `http://a.local:${port + 1}`), 403, "a page on another port");
    assert.equal(await readFile(home, "utf8"), base);
    assert.match(base, /a\.local:\d+\n.*\[::1\]:\d+\n$/s);
  });
});

test("frontmatter cannot pull a file from outside the root into the site", async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), "minidoc-"));
  const outside = await mkdtemp(path.join(os.tmpdir(), "minidoc-outside-"));
  t.after(async () => {
    await rm(root, { recursive: true, force: true });
    await rm(outside, { recursive: true, force: true });
  });
  await writeFile(path.join(outside, "secret.txt"), "secret");
  await mkdir(path.join(root, "pages"));
  await writeFile(
    path.join(root, "config.yaml"),
    ["var:", "  aside: { file: aside.html }", "build:", "  - pages: { dir: pages }", '    output: "dist/{{file.stem}}.html"', '    input: "{{aside}}{{page}}"', ""].join("\n"),
  );
  await writeFile(path.join(root, "aside.html"), "<aside></aside>");
  const steer = path.relative(path.join(root, "pages"), path.join(outside, "secret.txt"));
  await writeFile(path.join(root, "pages", "a.md"), `---\naside:\n  file: ${steer}\n  transform: none\n---\nhi\n`);

  await assert.rejects(run({ fs: nodeFs(root), glob: "config.yaml" }), /Path outside the project root/);
});

test("a page's write that arrives as a build lands does not reload that page", async (t) => {
  const root = await site();
  const gate = await mkdtemp(path.join(os.tmpdir(), "minidoc-gate-"));
  const at = (name) => path.join(gate, name);
  await writeFile(
    path.join(root, "src", "build.mjs"),
    [
      build,
      'import { existsSync, writeFileSync } from "node:fs";',
      `if (existsSync(${JSON.stringify(at("hold"))})) {`,
      `  writeFileSync(${JSON.stringify(at("reached"))}, "");`,
      `  while (!existsSync(${JSON.stringify(at("release"))})) await new Promise((resolve) => setTimeout(resolve, 2));`,
      "}",
      "",
    ].join("\n"),
  );
  const server = await dev({ ...options(root), edit: ["content"] });
  t.after(async () => {
    server.stop();
    await rm(root, { recursive: true, force: true });
    await rm(gate, { recursive: true, force: true });
  });
  const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const writer = await stream(server, "writer");
  const other = await stream(server, "other");
  const heard = hear(writer, "never said");
  const told = hear(other, "never said");
  const base = await (await file(server, "content/home.md")).text();

  await writeFile(at("hold"), "");
  const first = "Hello *first*.\n";
  await file(server, "content/home.md", { write: { text: first, base, page: "writer" } });
  for (let tries = 0; tries < 2000 && !existsSync(at("reached")); tries++) await pause(5);
  await file(server, "content/home.md", { write: { text: "Hello *second*.\n", base: first, page: "writer" } });
  await pause(20);
  await rm(at("hold"));
  await writeFile(at("release"), "");

  await until(server, "Hello *second*.");
  await pause(600);
  await writer.cancel();
  await other.cancel();
  const said = await heard;
  assert.match(said, /event: built/, "the page that wrote is told each build landed");
  assert.doesNotMatch(said, /data: reload/, "and keeps its caret");
  assert.match(await told, /data: reload/, "another page reloads");
});
