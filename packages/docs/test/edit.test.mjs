// The dev page edits every docs page through minidoc's reader and writer.
// Read and written back, each file is the same, byte for byte; a word
// changed in a block changes only that block. The static build carries
// nothing of the editor.
import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import * as Page from "@minidoc/live/src/edit/Page.mjs";
import { options } from "../src/options.mjs";

const content = fileURLToPath(new URL("../content/", import.meta.url));
const dist = fileURLToPath(new URL("../dist/", import.meta.url));
const all = (dir, ext) =>
  readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? all(path, ext) : path.endsWith(ext) ? [path] : [];
  });
const files = all(content, ".md").sort();
const reads = () => true;

test("every docs page read into the editor and written back is the same file", () => {
  for (const file of files) {
    const text = readFileSync(file, "utf8");
    const page = Page.read(text, options);
    assert.equal(Page.write(page, Page.held(page), reads), text, relative(content, file));
  }
});

/** The lines of each block in the file, by its id. A callout's close follows its last block. */
function ranges(page) {
  let at = page.file.front.split("\n").length - 1;
  let close = [];
  const out = {};
  for (const [id] of page.section.blocks) {
    const kept = page.file.blocks[id];
    if (!kept.inside) {
      at += close.length;
      close = [];
    }
    at += kept.gap.length;
    out[id] = [at, at + kept.lines.length];
    at += kept.lines.length;
    if (kept.kind.TAG === "Start") close = kept.kind.close;
  }
  return out;
}

test("one word changed in a block of a docs page changes only that block", () => {
  let checked = 0;
  for (const file of files) {
    const text = readFileSync(file, "utf8");
    const lines = text.split("\n");
    const blocks = Page.read(text, options).section.blocks;
    blocks.forEach(([id], index) => {
      const page = Page.read(text, options);
      const held = Page.held(page);
      const [, row] = held.blocks[index];
      const atom = /^:: \{\{(.+)\}\}$/.exec(row);
      const word = /[A-Za-z]{4,}/;
      if (atom) {
        const source = held.atoms.find((a) => a.id === atom[1]);
        if (!word.test(source.value)) return;
        source.value = source.value.replace(word, "Zzzz");
      } else {
        if (!word.test(row)) return;
        held.blocks[index] = [id, row.replace(word, "Zzzz")];
      }
      const back = Page.write(page, held, reads).split("\n");
      const [start, end] = ranges(page)[id];
      const name = `${relative(content, file)}, block ${index + 1}`;
      assert.deepEqual(back.slice(0, start), lines.slice(0, start), `${name}: the lines before it`);
      const after = lines.length - end;
      assert.deepEqual(back.slice(back.length - after), lines.slice(end), `${name}: the lines after it`);
      assert.notDeepEqual(back.slice(start, back.length - after), lines.slice(start, end), `${name}: the block itself`);
      checked++;
    });
  }
  assert.ok(checked > 400, `${checked} blocks checked`);
});

test("the static build writes no editor", () => {
  for (const page of all(dist, ".html")) {
    const html = readFileSync(page, "utf8");
    assert.doesNotMatch(html, /data-minidoc-edit|edit\.js|edit\.css/, relative(dist, page));
  }
});
