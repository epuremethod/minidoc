import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";
import { yamlBdd } from "./yaml-bdd/plugin.ts";

export default defineConfig({
  plugins: [
    yamlBdd({
      // The harness runtime: minidoc's public run API and the in-memory FS.
      runtime: fileURLToPath(new URL("./src/index.ts", import.meta.url)),
    }),
  ],
  test: {
    include: ["src/**/*.test.ts", "test/**/*.test.yaml"],
  },
});
