import { epureVitest, stepsResolver } from "@epure/vitest";
import { defineConfig } from "vitest/config";

// Two projects: the generator's fixtures, in Node, and the dev page's
// editor, in jsdom. The editor is linked from ../editor with its own
// node_modules: one React and one tilia, minidoc's, serve both.
export default defineConfig({
  test: {
    projects: [
      {
        plugins: [epureVitest()],
        test: { name: "minidoc", include: ["src/**/*.test.ts", "test/*.test.yaml"] },
      },
      {
        plugins: [epureVitest({ stepsResolver })],
        resolve: { dedupe: ["react", "react-dom", "tilia", "@tilia/react"] },
        test: { name: "edit", environment: "jsdom", include: ["test/edit/*.test.yaml"] },
      },
    ],
  },
});
