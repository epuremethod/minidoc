import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import type { FileSystem } from "../api/filesystem.ts";
import { makeMemoryFileSystem, run } from "../index.ts";

describe("run", () => {
  it("reads and parses each content file once, however many vars reference it", async () => {
    const fs = makeMemoryFileSystem({
      "config.yaml": [
        "var:",
        "  intro:",
        "    file: content/01.md",
        "  toc:",
        "    dir: content",
        "    transform: none",
        '    each: "- {{title}}"',
        "  chapters:",
        "    dir: content",
        "    transform: none",
        '    each: "{{body}}"',
        "build:",
        "  - output: out.txt",
        "    input: |-",
        "      {{toc}}",
        "      {{chapters}}",
      ].join("\n"),
      "content/01.md": "---\ntitle: One\n---\none",
      "content/02.md": "---\ntitle: Two\n---\ntwo",
    });
    const reads: string[] = [];
    const counting: FileSystem = {
      ...fs,
      readFile(path) {
        reads.push(path);
        return fs.readFile(path);
      },
    };

    await run({ fs: counting, glob: "config.yaml" });

    expect(reads.filter((path) => path.startsWith("content/")).sort()).toEqual(["content/01.md", "content/02.md"]);
    expect(await fs.readFile("out.txt")).toBe("- One\n- Two\none\ntwo");
  });

  it("runs every matched config and every build concurrently", async () => {
    const fs = makeMemoryFileSystem({
      "sites/a/config.yaml": [
        "build:",
        "  - output: one.txt",
        "    input: one",
        "  - output: two.txt",
        "    input: two",
      ].join("\n"),
      "sites/b/config.yaml": [
        "build:",
        "  - output: three.txt",
        "    input: three",
        "  - output: four.txt",
        "    input: four",
      ].join("\n"),
    });
    let active = 0;
    let peak = 0;
    const delayed: FileSystem = {
      ...fs,
      async writeFile(path, content) {
        active += 1;
        peak = Math.max(peak, active);
        await new Promise((resolve) => setTimeout(resolve, 10));
        await fs.writeFile(path, content);
        active -= 1;
      },
    };

    await run({ fs: delayed, glob: "sites/**/config.yaml" });

    expect(peak).toBe(4);
    await expect(Promise.all(["one", "two"].map((name) => fs.readFile(`sites/a/${name}.txt`)))).resolves.toEqual([
      "one",
      "two",
    ]);
    await expect(Promise.all(["three", "four"].map((name) => fs.readFile(`sites/b/${name}.txt`)))).resolves.toEqual([
      "three",
      "four",
    ]);
  });

  it("fails loud when the config glob matches nothing", async () => {
    await expect(run({ fs: makeMemoryFileSystem(), glob: "**/config.yaml" })).rejects.toThrow(
      'No config files match "**/config.yaml"',
    );
  });

  it("overrides named transforms while retaining the other defaults", async () => {
    const fs = makeMemoryFileSystem({
      "config.yaml": [
        "var:",
        "  markdown:",
        "    file: content.md",
        "  html:",
        "    file: content.html",
        "build:",
        "  - output: out.txt",
        '    input: "{{markdown}}/{{html}}"',
      ].join("\n"),
      "content.md": "custom",
      "content.html": "<b>plain</b>",
    });

    await run({
      fs,
      glob: "config.yaml",
      transform: { md: (text: string) => text.toUpperCase() },
    });

    expect(await fs.readFile("out.txt")).toBe("CUSTOM/<b>plain</b>");
  });

  it("uses the Node filesystem when fs is omitted", async () => {
    const dir = await mkdtemp(join(tmpdir(), "minidoc-run-"));
    try {
      const config = join(dir, "config.yaml");
      await writeFile(config, ["build:", "  - output: out.txt", "    input: built"].join("\n"));

      await run({ glob: config });

      expect(await readFile(join(dir, "out.txt"), "utf8")).toBe("built");
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});
