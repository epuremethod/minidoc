import { parse } from "yaml";
import { readScalarVars } from "./config.ts";

/** Leading `---` block: `---\n<yaml>\n---\n` (or closing `---` at end of file). */
const FRONTMATTER = /^---\n(?:([\s\S]*?)\n)?---(?:\n|$)/;

/**
 * Split an optional leading YAML frontmatter block off a content file.
 * Frontmatter values follow the same scalar rules as `var`. `where` locates
 * the file in error messages.
 */
export function splitFrontmatter(text: string, where: string): { vars: Record<string, string>; body: string } {
  if (!text.startsWith("---\n")) {
    return { vars: {}, body: text };
  }
  const match = FRONTMATTER.exec(text);
  if (!match) {
    throw new Error(`${where}: unterminated frontmatter (missing closing "---" line)`);
  }
  const vars = readScalarVars(match[1] === undefined ? undefined : parse(match[1]), `${where}: frontmatter`);
  return { vars, body: text.slice(match[0].length) };
}
