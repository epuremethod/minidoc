// minidoc serving its own documentation: watch, rebuild, live reload, and
// each page an editor of its markdown.
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { dev } from "@minidoc/core";
import { bundled } from "./bundle.mjs";

// `--port` serves on that port for this run; the remembered one stays as written.
const { values } = parseArgs({ options: { port: { type: "string" } } });

// The build marks each file's body and loads the editor: the build script
// runs in a process of its own, which takes this variable with it.
process.env.MINIDOC_EDIT = "1";

await bundled(fileURLToPath(new URL("../dist/", import.meta.url)), { watch: true });

await dev({
  glob: "content/config.yaml",
  build: "src/build.mjs",
  edit: ["content"],
  // The site is built from the library next door — edit it, see it.
  watch: ["../core/src", "../blocks/src", "../blocks/test", "../blocks/blocks.css", "../blocks/themes"],
  ...(values.port && { port: Number(values.port) }),
});
