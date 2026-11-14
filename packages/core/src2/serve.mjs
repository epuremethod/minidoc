// The croquis's server: each page drawn from the sync's files on each
// request, the client bundled once at the start, the folder's other files
// served as they are, and the sync: a WebSocket to each open page, and a
// watcher on the folder. `pnpm dev` runs it under `node --watch-path=src2`,
// so a change to the croquis restarts it, and each page reloads.
import { createHash } from "node:crypto";
import { watch } from "node:fs";
import { mkdir, readdir, readFile, rename, stat, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { WebSocketServer } from "ws";
import * as Render from "./Render.mjs";
import * as Site from "./Site.mjs";
import * as Sync from "./Sync.mjs";
import * as Parts from "./parts.mjs";

const here = fileURLToPath(new URL(".", import.meta.url));
const core = fileURLToPath(new URL("..", import.meta.url));
// The blocks' stylesheet and theme, which draw a quote or a `:::` block.
const blocks = fileURLToPath(new URL("../../blocks/", import.meta.url));

// One React, one tilia and one runtime in the page: this package's.
const shared = /^(react|react-dom|tilia|@tilia\/react|@rescript\/react|@rescript\/runtime)(\/.*)?$/;
const one = {
  name: "one-copy",
  setup(build) {
    build.onResolve({ filter: shared }, (args) =>
      args.pluginData === "shared" ? undefined : build.resolve(args.path, { kind: args.kind, resolveDir: core, pluginData: "shared" }),
    );
  },
};

/** Whether the sync reads a file of the folder: a markdown file, the template, or a component. */
const synced = (name) => Site.isMarkdown(name) || name === Render.templateFile || Site.isComponent(name);

/** The folder's files, by name: the markdown files and the template, with their text, and the images, with none. */
async function read(folder) {
  const names = [
    ...(await readdir(folder, { withFileTypes: true })).filter((entry) => entry.isFile()).map((entry) => entry.name),
    ...(await Parts.pathsOf(folder)),
  ];
  const images = (await readdir(join(folder, Site.imagesFolder), { withFileTypes: true }).catch(() => []))
    .filter((entry) => entry.isFile())
    .map((entry) => Site.imagesFolder + entry.name)
    .filter(Site.isImage);
  return Object.fromEntries([
    ...(await Promise.all(names.filter(synced).map(async (name) => [name, await readFile(join(folder, name), "utf8")]))),
    ...images.map((path) => [path, ""]),
  ]);
}

/** A port drawn from the folder's path: the same folder keeps its address across restarts. */
const portOf = (folder) => 11000 + (createHash("sha1").update(folder).digest().readUInt32BE(0) % 21768);

const types = {
  ".css": "text/css",
  ".js": "text/javascript",
  ".html": "text/html",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
};

// The base the pages are served under: behind maia, `/serve/<project>/`,
// with the prefix left on each request. The server's own address, with no
// prefix, serves the same pages. Links in a page are relative, so they stay
// under the address it was opened at.
const base = (process.env.MAIA_BASE ?? "/").replace(/\/?$/, "/");

export async function serve(folder) {
  const root = resolve(folder);
  const builtin = await readFile(join(here, "template.html"), "utf8");
  const sync = Sync.make(await read(root));

  // The folder's components, for Node and for the page, built again on a
  // change of `components/`. A component that does not build keeps the
  // last good build, and its error shows on each page until it builds.
  let components = {};
  let script = "";
  let broken = null;
  const build = async () => {
    const paths = await Parts.pathsOf(root);
    try {
      [components, script] = await Promise.all([Parts.forNode(root, paths), Parts.forPage(root, paths, [one])]);
      broken = null;
    } catch (error) {
      broken = String(error?.message ?? error);
      console.error(`minidoc: ${broken}`);
    }
  };
  await build();

  // The open pages, by the number the sync knows them by.
  const sockets = new Map();
  let opened = 0;
  // The messages of the sync, in order: a write waits for the disk before
  // the next message goes, so a page hears "saved" once the file is written.
  let queue = Promise.resolve();
  const dispatch = (sent) => {
    queue = queue.then(async () => {
      for (const { to, message } of sent) {
        const where = Sync.where(to);
        const json = Sync.wire(message);
        if (where === "disk") {
          if (json.writes !== undefined) await writeFile(join(root, json.writes), json.text);
          else if (json.stores !== undefined) {
            await mkdir(join(root, Site.imagesFolder), { recursive: true });
            await writeFile(join(root, json.stores), Buffer.from(json.bytes, "base64"));
          } else if (json.moves !== undefined) await rename(join(root, json.moves), join(root, json.as));
        } else {
          const text = JSON.stringify(json);
          for (const [page, socket] of sockets) if (where === "all" || where === page) socket.send(text);
        }
      }
    }).catch((error) => console.error(`minidoc: ${error?.message ?? error}`));
  };

  // A change on disk: each file once its events settle. An image is
  // there or not; its bytes stay on disk.
  const settling = new Map();
  watch(root, { recursive: true }, (_event, name) => {
    if (!name) return;
    name = name.split("\\").join("/");
    if (!synced(name) && !Site.isImage(name)) return;
    clearTimeout(settling.get(name));
    settling.set(name, setTimeout(async () => {
      settling.delete(name);
      if (Site.isComponent(name)) await build();
      const there = Site.isImage(name)
        ? await stat(join(root, name)).then((found) => (found.isFile() ? "" : undefined), () => undefined)
        : await readFile(join(root, name), "utf8").catch(() => undefined);
      dispatch(Sync.changed(sync, name, there));
    }, 40));
  });
  const server = createServer(async (req, res) => {
    const send = (status, type, body) => {
      res.writeHead(status, { "content-type": `${type}; charset=utf-8`, "cache-control": "no-store" });
      res.end(body);
    };
    try {
      const pathname = decodeURIComponent(new URL(req.url, "http://x").pathname);
      if (pathname === base.slice(0, -1)) {
        res.writeHead(301, { location: base });
        return res.end();
      }
      const path = (pathname.startsWith(base) ? pathname.slice(base.length) : pathname).replace(/^\/+/, "");
      if (path === "__minidoc/client.js") return send(200, "text/javascript", script);
      if (path === "__minidoc/minidoc.css") return send(200, "text/css", await readFile(join(here, "minidoc.css")));
      if (path === "__minidoc/editor.css") return send(200, "text/css", await readFile(join(here, "editor.css")));
      if (path === "__minidoc/blocks.css") return send(200, "text/css", await readFile(join(blocks, "blocks.css")));
      if (path === "__minidoc/soft.css") return send(200, "text/css", await readFile(join(blocks, "themes/soft.css")));
      const site = Sync.site(sync);
      if (site.pages.length === 0) return send(404, "text/plain", `${folder}: the folder holds no markdown file`);
      const href = path === "" ? (Site.pageAt(site, "index.html") ? "index.html" : site.pages[0].href) : path;
      const page = Site.pageAt(site, href);
      if (page) {
        if (broken) return send(500, "text/plain", `components/ does not build:\n${broken}`);
        const html = Render.page(site, page, sync.template ?? builtin, true, components);
        return html.TAG === "Ok" ? send(200, "text/html", html._0) : send(500, "text/plain", html._0);
      }
      // The template is never a page, nor a file to serve.
      if (path === Render.templateFile) {
        res.writeHead(302, { location: site.pages[0].href });
        return res.end();
      }
      const file = resolve(root, path);
      if (!file.startsWith(root + "/")) return send(403, "text/plain", "outside the folder");
      const body = await readFile(file).catch(() => null);
      if (body === null) return send(404, "text/plain", `${path} is not in ${folder}`);
      res.writeHead(200, { "content-type": types[extname(file)] ?? "application/octet-stream", "cache-control": "no-store" });
      res.end(body);
    } catch (error) {
      send(500, "text/plain", String(error?.stack ?? error));
    }
  });
  const sockets_ = new WebSocketServer({ noServer: true, maxPayload: 64 * 1024 * 1024 });
  server.on("upgrade", (req, socket, head) => {
    const pathname = new URL(req.url, "http://x").pathname;
    const path = (pathname.startsWith(base) ? pathname.slice(base.length) : pathname).replace(/^\/+/, "");
    if (path !== "__minidoc/sync") return socket.destroy();
    sockets_.handleUpgrade(req, socket, head, (ws) => {
      const page = String(++opened);
      sockets.set(page, ws);
      ws.on("message", (data) => {
        let message;
        try {
          message = JSON.parse(String(data));
        } catch {
          return;
        }
        if (typeof message.opens === "string") dispatch(Sync.opens(sync, page, message.opens, Number(message.on)));
        else if (typeof message.saves === "string")
          dispatch(Sync.saves(sync, page, message.saves, Number(message.on), String(message.text)));
        else if (typeof message.stores === "string")
          dispatch(Sync.stores(sync, page, message.stores, String(message.bytes)));
        else if (typeof message.renames === "string")
          dispatch(Sync.renames(sync, page, message.renames, String(message.as)));
      });
      ws.on("close", () => {
        sockets.delete(page);
        Sync.closes(sync, page);
      });
    });
  });

  const port = Number(process.env.PORT) || portOf(root);
  await new Promise((done, fail) => server.once("error", fail).listen(port, "127.0.0.1", done));
  console.log(`minidoc: ${folder} at http://localhost:${port}${base}`);
  return server;
}
