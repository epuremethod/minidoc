import { run } from "./index.ts";

const pattern = process.argv[2];
if (!pattern) {
  console.error("Usage: minidoc <configGlob>");
  process.exit(1);
}
run({ glob: pattern }).catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
