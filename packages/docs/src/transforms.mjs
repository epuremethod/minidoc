// The site's own `md` transform: marked, plus syntax coloring for the YAML
// examples. Build-time only — the deployed page is still static HTML.
import { Marked } from "marked";

const escapeHtml = (text) =>
  text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const refs = (html) =>
  html.replace(/\{\{[^{}]*\}\}/g, '<span class="tok-ref">$&</span>');

// A `#` starts a comment only outside quotes, at the start or after a space.
const commentIndex = (line) => {
  let quote = null;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quote) {
      if (c === quote) quote = null;
    } else if (c === "'" || c === '"') {
      quote = c;
    } else if (c === "#" && (i === 0 || line[i - 1] === " ")) {
      return i;
    }
  }
  return -1;
};

// Quoted strings become one span each, {{refs}} light up everywhere else too.
const value = (raw) => {
  const escaped = escapeHtml(raw);
  let html = "";
  let last = 0;
  for (const m of escaped.matchAll(/'[^']*'|"[^"]*"/g)) {
    html += refs(escaped.slice(last, m.index));
    html += `<span class="tok-str">${refs(m[0])}</span>`;
    last = m.index + m[0].length;
  }
  return html + refs(escaped.slice(last));
};

const keyLine = /^(\s*(?:- )?)([A-Za-z_][\w.]*):(?=\s|$)/;

const yamlLine = (line) => {
  const ci = commentIndex(line);
  const code = ci === -1 ? line : line.slice(0, ci);
  const comment =
    ci === -1 ? "" : `<span class="tok-com">${escapeHtml(line.slice(ci))}</span>`;
  const key = keyLine.exec(code);
  if (!key) return value(code) + comment;
  const rest = code.slice(key[0].length);
  return `${key[1]}<span class="tok-key">${escapeHtml(key[2])}</span>:${value(rest)}${comment}`;
};

const yamlHtml = (code) => code.split("\n").map(yamlLine).join("\n");

const marked = new Marked({
  renderer: {
    code({ text, lang }) {
      const cls = lang ? ` class="language-${escapeHtml(lang)}"` : "";
      const body =
        lang === "yaml" || lang === "yml" ? yamlHtml(text) : escapeHtml(text);
      return `<pre><code${cls}>${body}\n</code></pre>\n`;
    },
  },
});

export const md = (text) => marked.parse(text);
