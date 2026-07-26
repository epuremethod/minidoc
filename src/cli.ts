import { run } from "./index.ts";
import { makeNodeFileSystem } from "./services/node-filesystem.ts";

const configPath = process.argv[2];
if (!configPath) {
  console.error("Usage: minidoc <configPath>");
  process.exit(1);
}
run(makeNodeFileSystem(), configPath).catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
