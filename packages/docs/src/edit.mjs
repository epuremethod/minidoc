// The dev page's editor: each file's body, marked by the build under
// MINIDOC_EDIT, becomes its editor. Bundled by `dev.mjs`, never by the
// site's build.
import "@epure/blocks/live.css";
import "@epure/minidoc/edit.css";
import { mount } from "@epure/minidoc/edit";
import { options } from "./options.mjs";

for (const element of document.querySelectorAll("[data-minidoc-edit]")) {
  mount(element, element.dataset.minidocEdit, options);
}
