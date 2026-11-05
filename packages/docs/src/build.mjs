import { fileURLToPath } from "node:url";
import { nodeFs, run } from "@minidoc/core";
import { plates } from "./plates.mjs";
import { md } from "./transforms.mjs";

const root = new URL("../", import.meta.url);

// The output is written over, never emptied first: `dev` serves it while
// this runs, and after a failed build it is all there is.
export async function build() {
  await run({
    fs: nodeFs(fileURLToPath(root).replace(/\/$/, ""), { allow: ["../blocks"] }),
    glob: "content/config.yaml",
    transform: { md, plates },
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  await build();
}
