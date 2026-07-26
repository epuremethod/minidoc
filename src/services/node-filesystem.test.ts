import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expect, it } from "vitest";
import { makeNodeFileSystem } from "./node-filesystem.ts";

it("copies bytes without decoding them as text", async () => {
  const dir = await mkdtemp(join(tmpdir(), "minidoc-"));
  try {
    const source = join(dir, "source.bin");
    const output = join(dir, "nested", "output.bin");
    const content = Buffer.from([0, 255, 128, 10]);
    await writeFile(source, content);

    await makeNodeFileSystem().copy(source, output);

    expect(await readFile(output)).toEqual(content);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});
