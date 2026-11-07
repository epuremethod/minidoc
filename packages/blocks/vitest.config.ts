import { fileURLToPath } from "node:url";
import { epureVitest, stepsResolver } from "@epure/vitest";
import { defineConfig } from "vitest/config";

const liveSteps = fileURLToPath(new URL("./test/live/steps.ts", import.meta.url));
const contract = fileURLToPath(new URL("./test/html.test.yaml", import.meta.url));

// Two projects: the blocks written as HTML, in Node, and the blocks drawn
// live, in jsdom. The blocks' HTML contract runs in both, with live's steps
// in the second: each of its scenarios must hold when drawn live.
export default defineConfig({
  test: {
    projects: [
      {
        plugins: [epureVitest()],
        test: { name: "blocks", include: ["test/*.test.yaml"] },
      },
      {
        plugins: [epureVitest({ stepsResolver: (path) => (path === contract ? liveSteps : stepsResolver(path)) })],
        test: { name: "live", environment: "jsdom", include: ["test/live/*.test.yaml", "test/html.test.yaml"] },
      },
    ],
  },
});
