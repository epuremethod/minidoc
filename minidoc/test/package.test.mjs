import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

test("packages typed ESM for Node, Bun, and file dependencies", async () => {
  const temp = await mkdtemp(path.join(os.tmpdir(), "minidoc-package-"));
  try {
    await writeFile(
      path.join(temp, "package.json"),
      JSON.stringify({
        private: true,
        type: "module",
        dependencies: { "@epure/minidoc": `file:${root}` },
      }),
    );
    exec("pnpm", ["install", "--ignore-scripts"], temp);

    await writeFile(
      path.join(temp, "config.yaml"),
      ["var:", "  greeting: Hello", "build:", "  - output: out.txt", '    input: "{{greeting}}"'].join("\n"),
    );
    await writeFile(
      path.join(temp, "run.mjs"),
      [
        'import { run, nodeFs } from "@epure/minidoc";',
        'await run({ fs: nodeFs(process.cwd()), glob: "config.yaml" });',
      ].join("\n"),
    );
    exec("node", ["run.mjs"], temp);
    assert.equal(await readFile(path.join(temp, "out.txt"), "utf8"), "Hello");

    await writeFile(
      path.join(temp, "run.ts"),
      [
        'import { dev, run, watch } from "@epure/minidoc";',
        "const build: typeof run = run;",
        "const serve: (root: string) => Promise<number> = async (root) =>",
        '  (await dev({ glob: "config.yaml", build: "src/build.mjs", root, serve: "dist" })).port;',
        "const stop: (root: string) => Promise<void> = async (root) =>",
        '  (await watch({ glob: "config.yaml", root })).stop();',
        "void build;",
        "void serve;",
        "void stop;",
      ].join("\n"),
    );
    exec("bun", ["run.ts"], temp);

    await writeFile(
      path.join(temp, "tsconfig.json"),
      JSON.stringify({
        compilerOptions: {
          module: "NodeNext",
          moduleResolution: "NodeNext",
          noEmit: true,
          strict: true,
        },
        include: ["run.ts"],
      }),
    );
    exec(path.join(root, "node_modules", ".bin", "tsc"), ["-p", "tsconfig.json"], temp);

    exec("pnpm", ["pack", "--pack-destination", temp], root);
    const archive = (await readdir(temp)).find((file) => file.endsWith(".tgz"));
    assert.ok(archive);
    const files = exec("tar", ["-tzf", path.join(temp, archive)], temp).trim().split("\n");
    assert(files.includes("package/dist/index.mjs"));
    assert(files.includes("package/dist/index.d.ts"));
    assert(files.includes("package/LICENSE"));
    assert(files.every((file) => !file.includes("/test/") && !file.includes("/lib/")));
  } finally {
    await rm(temp, { recursive: true, force: true });
  }
});

function exec(command, args, cwd) {
  return execFileSync(command, args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}
