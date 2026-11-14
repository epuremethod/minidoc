// The dev page's editor: each file's body, marked by the build under
// MINIDOC_EDIT, becomes its editor. Bundled by `dev.mjs`, never by the
// site's build. A site imports `mount` from `@minidoc/live/edit`; this one
// takes the package's sources, so a change to the editor shows without a
// build of its bundle.
import "@minidoc/live/live.css";
import "@minidoc/live/edit.css";
import { mount } from "@minidoc/live/src/edit.js";
import { options } from "./options.mjs";

for (const element of document.querySelectorAll("[data-minidoc-edit]")) {
  mount(element, element.dataset.minidocEdit, options);
}
