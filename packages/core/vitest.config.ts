import { epureVitest } from "@epure/vitest";
import { defineConfig } from "vitest/config";

// The croquis (src2, test2) draws the editor, linked from ../editor with
// node_modules of its own: one React and one tilia, this package's, serve
// both.
export default defineConfig({
  plugins: [epureVitest()],
  resolve: { dedupe: ["react", "react-dom", "tilia", "@tilia/react"] },
  test: { include: ["src/**/*.test.ts", "test/*.test.yaml", "test2/*.test.yaml"] },
});
