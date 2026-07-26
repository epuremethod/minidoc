import { describe, expect, it } from "vitest";
import type { Scope } from "../api/resolve.ts";
import { resolve } from "./resolve.ts";

const scope = (label: string, vars: Record<string, string>): Scope => ({ label, vars });

describe.concurrent("resolve", () => {
  it("substitutes a variable from a scope", () => {
    expect(resolve("Hello {{name}} !", [scope("var", { name: "Marmot" })], "test")).toBe("Hello Marmot !");
  });

  it("takes the most local scope first", () => {
    const scopes = [scope("page var", { name: "Local" }), scope("var", { name: "Global" })];
    expect(resolve("{{name}}", scopes, "test")).toBe("Local");
  });

  it("resolves to a fixpoint when values reference variables", () => {
    const scopes = [scope("var", { greeting: "Hello {{name}}", name: "{{animal}}", animal: "Marmot" })];
    expect(resolve("{{greeting}} !", scopes, "test")).toBe("Hello Marmot !");
  });

  it("leaves text without references untouched", () => {
    expect(resolve("plain text", [], "test")).toBe("plain text");
  });

  it("fails loud on an undefined variable", () => {
    expect(() => resolve("{{missing}}", [scope("var", {})], 'page "home" input')).toThrow(
      'Undefined variable {{missing}} in page "home" input (searched: var)',
    );
  });

  it("detects a direct cycle", () => {
    const scopes = [scope("var", { a: "{{b}}", b: "{{a}}" })];
    expect(() => resolve("{{a}}", scopes, "test")).toThrow("Variable cycle in test: a -> b -> a");
  });

  it("detects a self cycle", () => {
    const scopes = [scope("var", { a: "x{{a}}" })];
    expect(() => resolve("{{a}}", scopes, "test")).toThrow("Variable cycle in test: a -> a");
  });

  it("allows the same variable twice on different branches", () => {
    const scopes = [scope("var", { page: "{{title}} - {{title}}", title: "Doc" })];
    expect(resolve("{{page}}", scopes, "test")).toBe("Doc - Doc");
  });
});
