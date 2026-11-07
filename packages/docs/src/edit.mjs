// The dev page's editor: each file's body, marked by the build under
// MINIDOC_EDIT, becomes its editor. Bundled by `dev.mjs`, never by the
// site's build.
import "@minidoc/live/live.css";
import "@minidoc/edit/edit.css";
import { mount } from "@minidoc/edit";
import { options } from "./options.mjs";

for (const element of document.querySelectorAll("[data-minidoc-edit]")) {
  mount(element, element.dataset.minidocEdit, options);
}
