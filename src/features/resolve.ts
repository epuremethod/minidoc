import type { ListContent, ListValue, MappingValue, Scope, Value } from "../api/resolve.ts";

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
  if ("kind" in value) {
    if (value.kind === "list") {
      return value.items.map((item) => expand(item, scopes, active, where)).join("");
    }
    throw new Error(`Cannot render a frontmatter mapping directly in ${where}; reference one of its scalar paths`);
  }
  if ("source" in value) {
    return expandList(value, scopes, active);
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

function expandList(value: ListContent, scopes: readonly Scope[], active: readonly string[]): string {
  const source = lookup(scopes, value.source);
  if (source === undefined) {
    const searched = scopes.map((scope) => scope.label).join(", ") || "no scopes";
    throw new Error(`Undefined list "${value.source}" in ${value.where} (searched: ${searched})`);
  }
  if (!list(source)) {
    throw new Error(`${value.where}: "${value.source}" must resolve to a frontmatter list`);
  }
  if (source.items.length === 0) {
    return "";
  }
  const body = source.items
    .map((item) =>
      expand(value.each, [{ label: `${value.where} item`, vars: { item } }, ...scopes], active, value.where),
    )
    .join(value.join);
  if (value.template === undefined) {
    return body;
  }
  return expand(value.template, [{ label: `${value.where} template`, vars: { body } }, ...scopes], active, value.where);
}

function lookup(scopes: readonly Scope[], name: string): Value | undefined {
  for (const scope of scopes) {
    const direct = scope.vars[name];
    if (direct !== undefined) {
      return direct;
    }
    const [root = name, ...path] = name.split(".");
    let value = scope.vars[root];
    for (const part of path) {
      if (!mapping(value)) {
        value = undefined;
        break;
      }
      value = value.entries[part];
    }
    if (value !== undefined) {
      return value;
    }
  }
  return undefined;
}

function list(value: Value): value is ListValue {
  return typeof value !== "string" && "kind" in value && value.kind === "list";
}

function mapping(value: Value | undefined): value is MappingValue {
  return value !== undefined && typeof value !== "string" && "kind" in value && value.kind === "mapping";
}
