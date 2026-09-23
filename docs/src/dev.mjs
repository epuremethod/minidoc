// minidoc serving its own documentation: watch, rebuild, live reload.
import { dev } from "@epure/minidoc";

await dev({
  glob: "content/config.yaml",
  build: "src/build.mjs",
  // The site is built from the library next door — edit it, see it.
  watch: ["../minidoc/src"],
});
