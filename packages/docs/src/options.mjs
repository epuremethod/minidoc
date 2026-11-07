// The blocks' options of the site: the story callout, and code fences
// colored by Prism. The `md` transform and the editor of the dev page both
// read them, so a block drawn while editing is the block on the page.
import Prism from "prismjs";
// Each language registers itself on the Prism that `prismjs` sets up, in
// Node as in a browser; Prism's own `loadLanguages` runs only in Node.
import "prismjs/components/prism-yaml.js";
import "prismjs/components/prism-typescript.js";
import "prismjs/components/prism-bash.js";
import "prismjs/components/prism-markdown.js";

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

export const options = {
  callouts: { story: "Story" },
  markdown: (md) => md.use((it) => { it.options.highlight = highlight; }),
};
