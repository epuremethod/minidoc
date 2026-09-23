// The dev runner against a real filesystem and a real socket — the two things
// the YAML fixtures cannot stand in for.

import assert from "node:assert/strict";
import net from "node:net";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { dev, nodeFs, watch } from "../src/Minidoc.res.mjs";

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
  `import { nodeFs, run } from "${path.join(here, "..", "src", "Minidoc.res.mjs")}";`,
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

test("dev serves the output and rebuilds what changed", async (t) => {
  const root = await site();
  const server = await dev(options(root));
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
    assert.match(page, /EventSource\("\/__minidoc"\)/);
    // injected where the page ends, not appended past it
    assert.ok(page.endsWith("</script></body></html>"));
  });

  await t.test("tells the page to reload when a build lands", async () => {
    const stream = await fetch(`http://127.0.0.1:${server.port}/__minidoc`);
    const reader = stream.body.getReader();
    await writeFile(path.join(root, "content", "home.md"), "Hello *again*.\n");
    let said = "";
    while (!said.includes("data: reload")) {
      const { value, done } = await reader.read();
      if (done) break;
      said += new TextDecoder().decode(value);
    }
    await reader.cancel();
    assert.match(said, /data: reload/);
    assert.match(await until(server, "Hello *again*."), /Hello \*again\*\./);
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

test("the port is remembered, and given up when the machine took it", async (t) => {
  const root = await site();
  t.after(() => rm(root, { recursive: true, force: true }));

  const first = await dev(options(root));
  const drawn = first.port;
  first.stop();

  const again = await dev(options(root));
  assert.equal(again.port, drawn, "the same site keeps the same address");
  again.stop();

  const squatter = net.createServer();
  await new Promise((resolve) => squatter.listen(drawn, "127.0.0.1", resolve));
  const moved = await dev(options(root));
  t.after(() => {
    moved.stop();
    squatter.close();
  });
  assert.notEqual(moved.port, drawn);
  assert.equal(port(await readFile(path.join(root, "config.yaml"), "utf8")), moved.port);
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
