import { Given } from "@epure/vitest";
import { expect } from "vitest";
import * as Storage from "@epure/editor/src/domain/feature/Storage.res.mjs";
import * as Form from "@epure/editor/src/domain/feature/Form.res.mjs";
import { read as readBlock } from "@minidoc/live";
import * as Page from "../src/Page.res.mjs";

type Section = { id: string; blocks: [string, string][]; atoms: { id: string; format: string; value: unknown }[]; uses: unknown[] };
type Edit = { replace?: string; with?: string; after?: string; add?: string };

const options = {};
const reads = (source: string) => readBlock(source, options).read.TAG === "Ok";

/** The editor's name for a block's form, in the scenario's words. */
const forms: Record<string, (text: string) => string> = {
  paragraph: (text) => text,
  item: (text) => `- ${text}`,
  "title 1": (text) => `# ${text}`,
  "title 2": (text) => `## ${text}`,
  "title 3": (text) => `### ${text}`,
};

function named(form: unknown): string {
  if (form === "Paragraph") return "paragraph";
  if (form === "Item") return "item";
  if (typeof form === "object" && form !== null && "_0" in form) return `title ${(form as { _0: number })._0}`;
  throw new Error(`No name for the form ${JSON.stringify(form)}`);
}

/** Each block as the editor holds it: its form and its plain text, or an atom's format and first line. */
function shown(section: Section): string[] {
  const doc = Storage.read(section);
  return doc.blocks.map((block: { form: unknown; content: { text: string } }) => {
    const atom = /^\{\{(.+)\}\}$/.exec(block.content.text);
    if (block.form === "Display" && atom) {
      const held = section.atoms.find((a) => a.id === atom[1])!;
      return `${held.format}: ${String(held.value).split("\n")[0]}`;
    }
    return `${named(block.form)}: ${block.content.text}`;
  });
}

/** A person's edit, as the editor hands it on: the section with one block, or one atom's source, changed. */
function edited(section: Section, edit: Edit): Section {
  if (edit.replace !== undefined) {
    if (typeof edit.with !== "string") throw new Error(`"replace" needs "with"`);
    const atom = section.atoms.find((a) => String(a.value).includes(edit.replace!));
    if (atom) return { ...section, atoms: section.atoms.map((a) => (a === atom ? { ...a, value: String(a.value).replace(edit.replace!, edit.with!) } : a)) };
    const at = section.blocks.findIndex(([, row]) => row.includes(edit.replace!));
    if (at < 0) throw new Error(`No block holds "${edit.replace}"`);
    const blocks = section.blocks.map(([id, row], i): [string, string] => [id, i === at ? row.replace(edit.replace!, edit.with!) : row]);
    return { ...section, blocks };
  }
  if (edit.after !== undefined) {
    const [form, ...rest] = String(edit.add).split(": ");
    const make = forms[form];
    if (!make) throw new Error(`"add" starts with a form: ${Object.keys(forms).join(", ")}`);
    const at = section.blocks.findIndex(([, row]) => row.includes(edit.after!));
    if (at < 0) throw new Error(`No block holds "${edit.after}"`);
    const blocks = [...section.blocks];
    blocks.splice(at + 1, 0, [`new${at}`, Form.write(Form.read(make(rest.join(": ")))[0], rest.join(": "))]);
    return { ...section, blocks };
  }
  throw new Error(`An edit is "replace" with "with", or "after" with "add"`);
}

/**
 A page's markdown, the `file`, read into the editor. `blocks` lists what
 the editor holds. Each of the `edits` is handed on as the editor hands it,
 and the file is written after each. The last file written must be the
 `written`, or the `file` itself when nothing is said.
*/
Given("a page edited in place", (_steps, data) => {
  const { file, blocks, edits = [], written, ...unknown } = data as Record<string, unknown>;
  const extra = Object.keys(unknown);
  if (extra.length > 0) throw new Error(`Unknown key(s): ${extra.join(", ")} (a scenario takes "file", "blocks", "edits", "written")`);
  if (typeof file !== "string") throw new Error(`A scenario needs a "file": the page's markdown`);
  if (!Array.isArray(edits)) throw new Error(`"edits" is a list`);
  const page = Page.read(file, { options });
  let section: Section = Storage.write(Storage.read(page.section), "page");
  if (blocks !== undefined) expect(shown(section)).toEqual(blocks);
  let out = Page.write(page, section, reads);
  for (const edit of edits as Edit[]) {
    section = edited(section, edit);
    out = Page.write(page, section, reads);
  }
  expect(out).toBe(written ?? file);
});
