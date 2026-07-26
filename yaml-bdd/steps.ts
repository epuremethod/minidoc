/**
 * Step registry and runtime for YAML scenario suites. Slated for extraction
 * into @epure/vitest, next to its Gherkin `Given` registry.
 *
 * A steps module registers handlers with `given`; compiled suites run each
 * scenario by handing its data mapping to the background's given step.
 */
export type StepFn = (data: Record<string, unknown>) => void | Promise<void>;

const steps: Record<string, StepFn> = {};

/** Register the handler for scenarios whose background declares `given: <key>`. */
export function given(key: string, fn: StepFn): void {
  if (steps[key] !== undefined) {
    throw new Error(`Step "${key}" is already defined`);
  }
  steps[key] = fn;
}

/** @internal Used by compiled suites. */
export async function runScenario(key: string, data: Record<string, unknown>): Promise<void> {
  const fn = steps[key];
  if (fn === undefined) {
    throw new Error(`Missing step definition for given "${key}"`);
  }
  await fn(data);
}
