import type { Scope, Value } from "../api/resolve.ts";

/**
 * `{{name}}` — plain name substitution only (v1).
 * Future extensions, not built yet: escaping literal `{{`/`}}`, filters/pipes,
 * expressions.
 */
const REFERENCE = /\{\{\s*([A-Za-z_][A-Za-z0-9_.-]*)\s*\}\}/g;

/**
 * Substitute every `{{name}}` in `template` with its value from the first
 * scope (most local first) that defines it, recursively, until no reference
 * remains (fixpoint). A file var expands its body with the file's own
 * frontmatter as the most local scope, then runs its transform on the result.
 * A dir var expands its `each` template once per file — that file's
 * frontmatter and its content as `body` most local — and joins the items with
 * newlines. Undefined variables and reference cycles fail loud.
 *
 * `where` locates the template in error messages, e.g. `page "marmot" input`.
 */
export function resolve(template: string, scopes: readonly Scope[], where: string): string {
  return expand(template, scopes, [], where);
}

/** Expand a loaded value directly — a page whose `input` is itself a file/dir var. */
export function resolveValue(value: Value, scopes: readonly Scope[], where: string): string {
  return expandValue(value, scopes, [], where);
}

function expand(text: string, scopes: readonly Scope[], active: readonly string[], where: string): string {
  return text.replace(REFERENCE, (reference, name: string) => {
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
    return expandValue(value, scopes, [...active, name], where);
  });
}

function expandValue(value: Value, scopes: readonly Scope[], active: readonly string[], where: string): string {
  if (typeof value === "string") {
    return expand(value, scopes, active, where);
  }
  if ("items" in value) {
    return value.items
      .map((item) =>
        expand(
          value.each,
          [item.frontmatter, { label: value.where, vars: { body: item } }, ...scopes],
          active,
          value.where,
        ),
      )
      .join("\n");
  }
  return value.transform(expand(value.body, [value.frontmatter, ...scopes], active, value.where));
}

function lookup(scopes: readonly Scope[], name: string): Value | undefined {
  for (const scope of scopes) {
    const value = scope.vars[name];
    if (value !== undefined) {
      return value;
    }
  }
  return undefined;
}
