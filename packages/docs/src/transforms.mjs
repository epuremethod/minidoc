// The site's own `md` transform: the blocks package's markdown, with code
// fences colored by Prism. Build-time only — the deployed page is still
// static HTML.
import Prism from "prismjs";
import loadLanguages from "prismjs/components/index.js";
import { blocks } from "@epure/minidoc-blocks";

loadLanguages(["yaml", "typescript", "bash", "markdown"]);

const languages = {
  yaml: "yaml", yml: "yaml",
  html: "markup", xml: "markup", svg: "markup",
  js: "javascript", mjs: "javascript", javascript: "javascript",
  ts: "typescript", typescript: "typescript",
  sh: "bash", bash: "bash", shell: "bash",
  md: "markdown", markdown: "markdown",
};

const escapeHtml = (text) =>
  text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// A minidoc reference lights up in every language, on top of Prism's tokens.
// It never spans a tag, so a reference Prism split in two is left alone.
const refs = (html) =>
  html.replace(/\{\{[^{}<]*\}\}/g, '<span class="tok-ref">$&</span>');

function highlight(code, lang) {
  const name = languages[lang];
  const html = name ? Prism.highlight(code, Prism.languages[name], name) : escapeHtml(code);
  return `<pre class="code"><code class="language-${escapeHtml(lang || "text")}">${refs(html)}</code></pre>`;
}

const render = blocks({
  callouts: { story: "Story" },
  markdown: (md) => md.use((it) => { it.options.highlight = highlight; }),
});

// Showing minidoc's escape on the page needs a backtick inside a reference,
// which the escape itself cannot carry: sources write `&#96;` there, and code
// keeps it as the entity instead of escaping its ampersand.
export const md = (text) => render(text).replaceAll("&amp;#96;", "&#96;");
