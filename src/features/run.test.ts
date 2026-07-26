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

    await run(counting, "config.yaml");

    expect(reads.filter((path) => path.startsWith("content/")).sort()).toEqual(["content/01.md", "content/02.md"]);
    expect(await fs.readFile("out.txt")).toBe("- One\n- Two\none\ntwo");
  });
});
