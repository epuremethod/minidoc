import { defineConfig } from "vitest/config";
import { yamlBdd } from "./yaml-bdd/plugin.ts";

export default defineConfig({
  plugins: [yamlBdd()],
  test: {
    include: ["src/**/*.test.ts", "test/**/*.test.yaml"],
  },
});
