// The site's own components, the `.jsx` files of `components/`, built by
// esbuild: for Node, to draw the pages, and for the page, with the client.
// A component's name is its file's name. The folder has no `node_modules`:
// `react` comes from minidoc, and the JSX needs no import.
import { createRequire } from "node:module";
import { readdir } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import esbuild from "esbuild";
import * as Site from "./Site.mjs";

const require = createRequire(import.meta.url);
const here = fileURLToPath(new URL(".", import.meta.url));
const jsx = { jsx: "automatic", loader: { ".js": "jsx", ".jsx": "jsx" } };

/** A component's name: its file's name, with no extension. */
export const nameOf = (path) => path.slice(Site.componentsFolder.length).replace(/\.(jsx|js)$/, "");

/** The components of a folder, by path: `components/count.jsx`. */
export async function pathsOf(root) {
  const entries = await readdir(join(root, Site.componentsFolder), { withFileTypes: true }).catch(() => []);
  return entries
    .filter((entry) => entry.isFile())
    .map((entry) => Site.componentsFolder + entry.name)
    .filter(Site.isComponent)
    .sort();
}

/** CommonJS code run with minidoc's own `require`: one React for the server and the components. */
function run(code) {
  const module = { exports: {} };
  new Function("require", "module", "exports", code)(require, module, module.exports);
  return module.exports;
}

/** The components of a folder in memory, by name, from their texts: for the fixtures. */
export function fromTexts(files) {
  const components = {};
  for (const [path, text] of Object.entries(files)) {
    if (!Site.isComponent(path)) continue;
    const { code } = esbuild.transformSync(text, { loader: "jsx", jsx: "automatic", format: "cjs" });
    components[nameOf(path)] = run(code).default;
  }
  return components;
}

/** The module that names each component: `export { default as "count" } from "./components/count.jsx"`. */
const entry = (paths) => paths.map((path) => `export { default as ${JSON.stringify(nameOf(path))} } from "./${path}";`).join("\n");

/** The components of the folder `root`, built for Node, by name. */
export async function forNode(root, paths) {
  if (paths.length === 0) return {};
  const built = await esbuild.build({
    stdin: { contents: entry(paths), resolveDir: root, loader: "js" },
    bundle: true,
    platform: "node",
    format: "cjs",
    write: false,
    logLevel: "silent",
    external: ["react", "react/*", "react-dom", "react-dom/*"],
    ...jsx,
  });
  return run(built.outputFiles[0].text);
}

/** The page's code: the client, started with the folder's components. `plugins` keeps one React. */
export async function forPage(root, paths, plugins) {
  const imports = paths.map((path, index) => `import c${index} from "./${path}";`).join("\n");
  const names = paths.map((path, index) => `${JSON.stringify(nameOf(path))}: c${index}`).join(", ");
  const built = await esbuild.build({
    stdin: {
      contents: `import { start } from ${JSON.stringify(join(here, "Client.mjs"))};\n${imports}\nstart({ ${names} });`,
      resolveDir: root,
      loader: "js",
    },
    bundle: true,
    format: "esm",
    write: false,
    logLevel: "silent",
    define: { "process.env.NODE_ENV": '"development"' },
    plugins,
    ...jsx,
  });
  return built.outputFiles[0].text;
}
