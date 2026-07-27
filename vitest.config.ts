import { epureVitest } from "@epure/vitest";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [epureVitest()],
  test: {
    include: ["src/**/*.test.ts", "test/**/*.test.yaml"],
  },
});
