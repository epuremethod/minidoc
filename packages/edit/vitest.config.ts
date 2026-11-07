import { epureVitest, stepsResolver } from "@epure/vitest";
import { defineConfig } from "vitest/config";

// The editor is linked from ../editor with its own node_modules: one React
// and one tilia, minidoc's, serve both.
export default defineConfig({
  plugins: [epureVitest({ stepsResolver })],
  resolve: { dedupe: ["react", "react-dom", "tilia", "@tilia/react"] },
  test: {
    environment: "jsdom",
    include: ["test/**/*.test.yaml"],
  },
});
