import { fileURLToPath } from "node:url";
import { epureVitest, stepsResolver } from "@epure/vitest";
import { defineConfig } from "vitest/config";

const steps = fileURLToPath(new URL("./test/steps.ts", import.meta.url));
const contract = fileURLToPath(new URL("../blocks/test/html.test.yaml", import.meta.url));

// The blocks' HTML contract runs here too, with these steps: each of its
// scenarios must hold when drawn live.
export default defineConfig({
  plugins: [epureVitest({ stepsResolver: (path) => (path === contract ? steps : stepsResolver(path)) })],
  test: {
    environment: "jsdom",
    include: ["test/**/*.test.yaml", "../blocks/test/html.test.yaml"],
  },
});
