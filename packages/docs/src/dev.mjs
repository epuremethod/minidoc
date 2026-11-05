// minidoc serving its own documentation: watch, rebuild, live reload.
import { parseArgs } from "node:util";
import { dev } from "@minidoc/core";

// `--port` serves on that port for this run; the remembered one stays as written.
const { values } = parseArgs({ options: { port: { type: "string" } } });

await dev({
  glob: "content/config.yaml",
  build: "src/build.mjs",
  // The site is built from the library next door — edit it, see it.
  watch: ["../core/src", "../blocks/src", "../blocks/test", "../blocks/blocks.css", "../blocks/themes"],
  ...(values.port && { port: Number(values.port) }),
});
