// The three packages as a site installs them: packed, with `workspace:^`
// rewritten and the devDependencies removed, installed from their tarballs
// into an empty folder, imported in Node, Bun and TypeScript, and the page
// editor bundled for the browser.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdir, mkdtemp, readdir, readFile, realpath, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { after, before, test } from "node:test";
import { fileURLToPath } from "node:url";
import esbuild from "esbuild";

const packages = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const own = ["blocks", "core", "live"];

// Packages that are not on npm yet, packed from their repositories at the
// version they will be published at. Their scripts would build inside those
// repositories, so they are packed with scripts off, as built there.
const unpublished = async () => [
  { dir: path.resolve(packages, "../../tilia/react"), version: "6.0.2", dependencies: { tilia: "^6.0.1" } },
  { dir: await realpath(path.join(packages, "live/node_modules/@epure/editor")), version: "0.1.0-beta.3" },
  {
    dir: await realpath(path.join(packages, "live/node_modules/@tilia/editor")),
    version: "0.1.0-beta.3",
    dependencies: { "@epure/editor": "^0.1.0-beta.3" },
  },
];

let temp;
/** Each package's tarball, by name. */
const tarballs = {};
/** Each of our packages' packed manifest, by name. */
const manifests = {};
/** Each of our packages' packed files, by name. */
const contents = {};

before(async () => {
  temp = await mkdtemp(path.join(os.tmpdir(), "minidoc-package-"));
  await mkdir(path.join(temp, "packs"));
  for (const name of own) {
    const dir = path.join(packages, name);
    const archive = packIn(dir, path.join(temp, "packs"));
    const manifest = JSON.parse(exec("tar", ["-xzOf", archive, "package/package.json"], temp));
    tarballs[manifest.name] = archive;
    manifests[manifest.name] = manifest;
    contents[manifest.name] = exec("tar", ["-tzf", archive], temp).trim().split("\n");
  }
  for (const { dir, version, dependencies } of await unpublished()) {
    const scratch = await mkdtemp(path.join(temp, "local-"));
    const archive = packIn(dir, scratch, ["--config.ignore-scripts=true"]);
    exec("tar", ["-xzf", archive], scratch);
    const file = path.join(scratch, "package", "package.json");
    const manifest = JSON.parse(await readFile(file, "utf8"));
    manifest.version = version;
    Object.assign(manifest.dependencies ?? {}, dependencies);
    for (const key of ["scripts", "devDependencies", "clean-package"]) delete manifest[key];
    await writeFile(file, JSON.stringify(manifest, null, 2));
    const repacked = path.join(temp, "packs", `${manifest.name.replace("@", "").replace("/", "-")}-${version}.tgz`);
    exec("tar", ["-czf", repacked, "package"], scratch);
    tarballs[manifest.name] = repacked;
  }

  const local = Object.fromEntries(Object.entries(tarballs).map(([name, file]) => [name, `file:${file}`]));
  await writeFile(
    path.join(temp, "package.json"),
    JSON.stringify({
      private: true,
      type: "module",
      dependencies: {
        ...local,
        "@rescript/react": "^0.15.0",
        "@types/react": "^19.2.0",
        react: "^19.2.0",
        "react-dom": "^19.2.0",
        tilia: "^6.0.1",
      },
    }),
  );
  // A dependency on one of these, such as live's on `@minidoc/blocks@^0.2.0`,
  // takes its tarball too.
  await writeFile(
    path.join(temp, "pnpm-workspace.yaml"),
    ["overrides:", ...Object.entries(local).map(([name, spec]) => `  "${name}": "${spec}"`)].join("\n"),
  );
  exec("pnpm", ["install", "--ignore-scripts"], temp);
});

after(async () => {
  if (temp) await rm(temp, { recursive: true, force: true });
});

test("each tarball holds its bundle, its types and its compiled sources, and no devDependencies", () => {
  const expected = {
    "@minidoc/core": ["dist/index.mjs", "dist/index.d.ts", "dist/llms.txt", "dist/llms-full.txt", "src/index.js", "src/Minidoc.mjs"],
    "@minidoc/blocks": ["dist/index.mjs", "dist/index.d.ts", "src/index.js", "src/Blocks.mjs", "blocks.css", "themes/soft.css", "viewer.js"],
    "@minidoc/live": [
      "dist/index.mjs",
      "dist/index.d.ts",
      "dist/edit.mjs",
      "dist/edit.d.ts",
      "src/index.js",
      "src/Live.mjs",
      "src/edit/Edit.mjs",
      "live.css",
      "edit.css",
    ],
  };
  for (const [name, files] of Object.entries(expected)) {
    const packed = contents[name];
    for (const file of [...files, "rescript.json", "LICENSE"]) {
      assert(packed.includes(`package/${file}`), `${name} holds ${file}`);
    }
    assert(packed.every((file) => !file.includes("/test/") && !file.includes("/lib/")), `${name} holds no test or lib`);
    assert(packed.every((file) => !/\.res\.mjs$/.test(file)), `${name} holds no module of the old suffix`);
    const manifest = manifests[name];
    assert.equal(manifest.version, "0.2.0");
    assert.equal(manifest.devDependencies, undefined, `${name} has no devDependencies`);
    assert.equal(manifest.scripts, undefined, `${name} has no scripts`);
    assert(!JSON.stringify(manifest).includes("workspace:"), `${name} names no workspace`);
    assert(!JSON.stringify(manifest).includes("link:"), `${name} names no link`);
  }
  // React and the editor are live's alone.
  assert.equal(manifests["@minidoc/core"].peerDependencies, undefined);
  assert.equal(manifests["@minidoc/blocks"].peerDependencies, undefined);
  assert.equal(manifests["@minidoc/live"].dependencies["@minidoc/blocks"], "^0.2.0");
});

test("core runs a build in Node and Bun, and the three packages' types check", async () => {
  await writeFile(
    path.join(temp, "config.yaml"),
    ["var:", "  greeting: Hello", "build:", "  - output: out.txt", '    input: "{{greeting}}"'].join("\n"),
  );
  await writeFile(
    path.join(temp, "run.mjs"),
    ['import { run, nodeFs } from "@minidoc/core";', 'await run({ fs: nodeFs(process.cwd()), glob: "config.yaml" });'].join("\n"),
  );
  exec("node", ["run.mjs"], temp);
  assert.equal(await readFile(path.join(temp, "out.txt"), "utf8"), "Hello");

  await writeFile(
    path.join(temp, "run.ts"),
    [
      'import { dev, run, watch } from "@minidoc/core";',
      "const build: typeof run = run;",
      "const serve: (root: string) => Promise<number> = async (root) =>",
      '  (await dev({ glob: "config.yaml", build: "src/build.mjs", root, serve: "dist" })).port;',
      "const stop: (root: string) => Promise<void> = async (root) =>",
      '  (await watch({ glob: "config.yaml", root })).stop();',
      "void [build, serve, stop];",
    ].join("\n"),
  );
  exec("bun", ["run.ts"], temp);

  // The browser's packages are only type-checked.
  await writeFile(
    path.join(temp, "site.ts"),
    [
      'import { blocks, type Options } from "@minidoc/blocks";',
      'import { Drawing, read, type Value } from "@minidoc/live";',
      'import { mount } from "@minidoc/live/edit";',
      "const options: Options = {};",
      "const md: (source: string) => string = blocks(options);",
      'const value: Value = read("::: note\\nHi\\n:::", options);',
      'const edit = (element: Element): Promise<void> => mount(element, "content/home.md", options);',
      "void [md, value, edit, Drawing];",
    ].join("\n"),
  );

  await writeFile(
    path.join(temp, "tsconfig.json"),
    JSON.stringify({
      compilerOptions: {
        module: "NodeNext",
        moduleResolution: "NodeNext",
        lib: ["ES2022", "DOM"],
        noEmit: true,
        strict: true,
      },
      include: ["run.ts", "site.ts"],
    }),
  );
  exec(path.join(packages, "core", "node_modules", ".bin", "tsc"), ["-p", "tsconfig.json"], temp);
});

test("blocks write a page, and live reads a block, in Node", async () => {
  await writeFile(
    path.join(temp, "blocks.mjs"),
    [
      'import { blocks } from "@minidoc/blocks";',
      'import { read } from "@minidoc/live";',
      'const html = blocks({})("::: note\\nHi\\n:::");',
      'if (!html.includes("callout--note")) throw new Error(html);',
      'const value = read("::: note\\nHi\\n:::", {});',
      'if (value.read.TAG !== "Ok") throw new Error(JSON.stringify(value));',
    ].join("\n"),
  );
  exec("node", ["blocks.mjs"], temp);
});

test("a site bundles the page editor for the browser, with one React and one tilia", async () => {
  await writeFile(
    path.join(temp, "edit.mjs"),
    [
      'import "@minidoc/blocks/blocks.css";',
      'import "@minidoc/blocks/themes/soft.css";',
      'import "@minidoc/live/live.css";',
      'import "@minidoc/live/edit.css";',
      'import { mount } from "@minidoc/live/edit";',
      "for (const element of document.querySelectorAll(\"[data-minidoc-edit]\")) {",
      "  mount(element, element.dataset.minidocEdit, {});",
      "}",
    ].join("\n"),
  );
  const built = await esbuild.build({
    absWorkingDir: temp,
    entryPoints: ["edit.mjs"],
    outdir: "out",
    bundle: true,
    format: "esm",
    metafile: true,
    logLevel: "silent",
    loader: { ".woff": "file", ".woff2": "file", ".ttf": "file" },
    define: { "process.env.NODE_ENV": '"production"' },
  });
  assert.deepEqual(built.errors, []);
  const files = await readdir(path.join(temp, "out"));
  assert(files.includes("edit.js") && files.includes("edit.css"), files.join(", "));
  const copies = (name) =>
    new Set(
      Object.keys(built.metafile.inputs)
        .map((input) => input.match(new RegExp(`^(.*node_modules/${name.replace("/", "\\/")})/`))?.[1])
        .filter(Boolean),
    );
  for (const name of ["react", "react-dom", "tilia", "@tilia/react"]) {
    assert.equal(copies(name).size, 1, `${name}: ${[...copies(name)].join(", ")}`);
  }
});

/** Pack the package in `dir` into `destination`, and give the tarball's path. */
function packIn(dir, destination, flags = []) {
  const before = new Set(execFileSync("ls", [destination], { encoding: "utf8" }).split("\n"));
  exec("pnpm", ["pack", ...flags, "--pack-destination", destination], dir);
  const added = execFileSync("ls", [destination], { encoding: "utf8" })
    .split("\n")
    .filter((file) => file.endsWith(".tgz") && !before.has(file));
  assert.equal(added.length, 1, `one tarball from ${dir}`);
  return path.join(destination, added[0]);
}

function exec(command, args, cwd) {
  return execFileSync(command, args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}
