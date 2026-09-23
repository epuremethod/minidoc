import { rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { nodeFs, run } from "@epure/minidoc";
import { md } from "./transforms.mjs";

const root = new URL("../", import.meta.url);
const output = new URL("dist/", root);

export async function build() {
  await rm(output, { recursive: true, force: true });
  await run({
    fs: nodeFs(fileURLToPath(root).replace(/\/$/, "")),
    glob: "content/config.yaml",
    transform: { md },
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  await build();
}
