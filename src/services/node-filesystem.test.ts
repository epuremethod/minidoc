import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { describe, expect, it } from "vitest";
import { nodeFs } from "./node-filesystem.ts";

describe("nodeFs", () => {
  it("roots relative paths at a string or URL", async () => {
    const dir = await mkdtemp(join(tmpdir(), "minidoc-root-"));
    try {
      await writeFile(join(dir, "input.txt"), "rooted");

      expect(await nodeFs(dir).readFile("input.txt")).toBe("rooted");
      expect(await nodeFs(pathToFileURL(`${dir}/`)).readFile("input.txt")).toBe("rooted");
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("globs rooted files in deterministic order", async () => {
    const dir = await mkdtemp(join(tmpdir(), "minidoc-glob-"));
    try {
      await Promise.all([
        writeFile(join(dir, "b-config.yaml"), "b"),
        writeFile(join(dir, "a-config.yaml"), "a"),
        writeFile(join(dir, "notes.txt"), "ignored"),
      ]);

      expect(await nodeFs(dir).glob("*-config.yaml")).toEqual(["a-config.yaml", "b-config.yaml"]);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("caches reads by normalized absolute path and invalidates writes", async () => {
    const dir = await mkdtemp(join(tmpdir(), "minidoc-cache-"));
    try {
      const file = join(dir, "input.txt");
      await writeFile(file, "first");
      const fs = nodeFs(dir);

      expect(await fs.readFile("input.txt")).toBe("first");
      await writeFile(file, "changed outside");
      expect(await fs.readFile("./input.txt")).toBe("first");

      await fs.writeFile("input.txt", "written through adapter");
      expect(await fs.readFile("input.txt")).toBe("written through adapter");
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("copies bytes directly instead of using the read cache", async () => {
    const dir = await mkdtemp(join(tmpdir(), "minidoc-copy-"));
    try {
      const source = join(dir, "source.bin");
      const output = join(dir, "nested", "output.bin");
      const initial = Buffer.from([0, 1]);
      const current = Buffer.from([0, 255, 128, 10]);
      await writeFile(source, initial);
      const fs = nodeFs(dir);
      await fs.readFile("source.bin");
      await writeFile(source, current);

      await fs.copy("source.bin", "nested/output.bin");

      expect(await readFile(output)).toEqual(current);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});
