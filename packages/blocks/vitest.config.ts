import { epureVitest } from "@epure/vitest";
import { defineConfig } from "vitest/config";

// The blocks written as HTML, in Node. @minidoc/live runs the HTML contract,
// test/html.test.yaml, again with its own steps: each of its scenarios must
// hold when drawn live.
export default defineConfig({
  plugins: [epureVitest()],
  test: { name: "blocks", include: ["test/*.test.yaml"] },
});
