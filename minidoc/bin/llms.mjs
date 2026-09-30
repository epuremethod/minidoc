// Build dist/llms.txt and dist/llms-full.txt with minidoc itself, from the
// docs guide: part of `pnpm build`, so `prepack` puts them in the package.
import { fileURLToPath } from "node:url";
import { nodeFs, run } from "../src/Minidoc.res.mjs";

const root = fileURLToPath(new URL("../", import.meta.url)).replace(/\/$/, "");

await run({ fs: nodeFs(root), glob: "llms.yaml" });
