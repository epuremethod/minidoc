import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { Plugin } from "vite";
import { compile } from "./compile.ts";

/**
 * YAML-BDD: Vite glue turning `*.test.yaml` fixtures into Vitest suites.
 *
 * The fixture format and codegen live in `compile.ts` (yaml parsing +
 * sourcemaps, slated for extraction into @epure/vitest); what a scenario
 * means lives in the steps module resolved by `stepsResolver`, registered
 * through `steps.ts`.
 */
export type YamlBddOptions = {
  /** File suffix compiled into suites. Default: `.test.yaml`. */
  suffix?: string;
  /** Run scenarios concurrently. Default: true. */
  concurrent?: boolean;
  /** Resolve a fixture to its steps module. Default: {@link stepsResolver}. */
  stepsResolver?: (path: string) => string | null;
  /** Print each generated module. */
  debug?: boolean;
};

const runtimePath = fileURLToPath(new URL("./steps.ts", import.meta.url));

export function yamlBdd(options: YamlBddOptions = {}): Plugin {
  const suffix = options.suffix ?? ".test.yaml";
  const resolveSteps = options.stepsResolver ?? stepsResolver;
  return {
    name: "yaml-bdd",
    enforce: "pre",
    load(id) {
      const path = id.split("?")[0] ?? id;
      if (!path.endsWith(suffix)) {
        return;
      }
      return compile(path, {
        stepsPath: resolveSteps(path),
        runtimePath,
        concurrent: options.concurrent,
        debug: options.debug,
      });
    },
  };
}

/**
 * Same resolution as @epure/vitest: `base.test.yaml` finds `base.test.ts`,
 * then `base.steps.ts`, then a shared `steps.ts` next to the fixture
 * (each also tried with the other script extensions).
 */
export function stepsResolver(path: string): string | null {
  const stem = path.replace(/\.yaml$/, "");
  return (
    resolveModule(stem) ??
    resolveModule(stem.replace(/\.test$/, ".steps")) ??
    resolveModule(join(dirname(path), "steps"))
  );
}

function resolveModule(stem: string): string | null {
  for (const ext of [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"]) {
    const candidate = `${stem}${ext}`;
    if (existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}
