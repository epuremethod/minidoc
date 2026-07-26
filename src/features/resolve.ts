import type { Scope } from "../api/resolve.ts";

/**
 * `{{name}}` — plain name substitution only (v1).
 * Future extensions, not built yet: escaping literal `{{`/`}}`, filters/pipes,
 * expressions.
 */
const REFERENCE = /\{\{\s*([A-Za-z_][A-Za-z0-9_.-]*)\s*\}\}/g;

/**
 * Substitute every `{{name}}` in `template` with its value from the first
 * scope (most local first) that defines it, recursively, until no reference
 * remains (fixpoint). Undefined variables and reference cycles fail loud.
 *
 * `where` locates the template in error messages, e.g. `page "marmot" input`.
 */
export function resolve(template: string, scopes: readonly Scope[], where: string): string {
  const expand = (text: string, active: readonly string[]): string =>
    text.replace(REFERENCE, (reference, name: string) => {
      const cycleStart = active.indexOf(name);
      if (cycleStart >= 0) {
        const path = [...active.slice(cycleStart), name].join(" -> ");
        throw new Error(`Variable cycle in ${where}: ${path}`);
      }
      const value = lookup(scopes, name);
      if (value === undefined) {
        const searched = scopes.map((scope) => scope.label).join(", ") || "no scopes";
        throw new Error(`Undefined variable ${reference} in ${where} (searched: ${searched})`);
      }
      return expand(value, [...active, name]);
    });
  return expand(template, []);
}

function lookup(scopes: readonly Scope[], name: string): string | undefined {
  for (const scope of scopes) {
    const value = scope.vars[name];
    if (value !== undefined) {
      return value;
    }
  }
  return undefined;
}
