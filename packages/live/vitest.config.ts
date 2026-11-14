import { fileURLToPath } from "node:url";
import { epureVitest, stepsResolver } from "@epure/vitest";
import { defineConfig } from "vitest/config";

const liveSteps = fileURLToPath(new URL("./test/steps.ts", import.meta.url));
const contract = fileURLToPath(new URL("../blocks/test/html.test.yaml", import.meta.url));

// Two projects, both in jsdom: the blocks drawn live, and the page's
// editor. The blocks' HTML contract runs in the first, with live's steps:
// each of its scenarios must hold when drawn live. The editor is linked from
// ../editor with its own node_modules: one React and one tilia, this
// package's, serve both.
const dedupe = ["react", "react-dom", "tilia", "@tilia/react"];

export default defineConfig({
  test: {
    projects: [
      {
        plugins: [epureVitest({ stepsResolver: (path) => (path === contract ? liveSteps : stepsResolver(path)) })],
        resolve: { dedupe },
        test: { name: "live", environment: "jsdom", include: ["test/*.test.yaml", "../blocks/test/html.test.yaml"] },
      },
      {
        plugins: [epureVitest({ stepsResolver })],
        resolve: { dedupe },
        test: { name: "edit", environment: "jsdom", include: ["test/edit/*.test.yaml"] },
      },
    ],
  },
});
