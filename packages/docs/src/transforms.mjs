// The site's own transforms. `md` is the blocks package's markdown, with
// code fences colored by Prism: build-time only, the deployed page is still
// static HTML. The `edit…` transforms write the dev page's editor and
// write nothing in any other build.
import { blocks } from "@epure/blocks";
import { options } from "./options.mjs";

const render = blocks(options);

// Showing minidoc's escape on the page needs a backtick inside a reference,
// which the escape itself cannot carry: sources write `&#96;` there, and code
// keeps it as the entity instead of escaping its ampersand.
export const md = (text) => render(text).replaceAll("&amp;#96;", "&#96;");

// `pnpm docs:dev` sets MINIDOC_EDIT. Each file's body is then marked with
// the file it comes from, and the page loads the editor.
const editing = process.env.MINIDOC_EDIT === "1";
const attribute = (text) => text.replace(/&/g, "&amp;").replace(/"/g, "&quot;");

export const editFrom = (path) =>
  editing ? `<div class="minidoc-edit" data-minidoc-edit="${attribute(path.trim())}">` : "";
export const editTo = () => (editing ? "</div>" : "");
export const editScript = () =>
  editing ? `<link rel="stylesheet" href="./edit.css"><script type="module" src="./edit.js"></script>` : "";
