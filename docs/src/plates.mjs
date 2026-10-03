// The `plates` transform: a fixture of @epure/minidoc-blocks, drawn as one
// plate per scenario. Its value is the fixture's name. A plate has three
// columns: the markdown an author writes, the nodes the reader gives, and
// the page a reader sees. The page is a frame drawn as a screenshot, with
// fixed text above and below the block. The package does every step; this
// file only lays the three out.
//
// The fixture's `after` is the nodes a scenario expects. When the reader
// gives other nodes, the plate says so and shows the expected ones under
// them.

import { readFileSync } from "node:fs";
import { parse } from "yaml";
import { read, render, write } from "@epure/minidoc-blocks";

const fixtures = new URL("../../blocks/test/", import.meta.url);

const escape = (text) =>
  String(text).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

const slug = (text) =>
  text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

// The text around every block, the same on every plate.
const above = `<p class="shot__kicker">Release notes</p>
<h3 class="shot__title">Publishing the handbook</h3>
<p>Each release of the handbook goes through the same few steps. They are written down here, so that anyone on the team can run one.</p>`;
const below = `<p>The next section lists who signs off, and what each of them checks before the release goes out.</p>`;

function shot(inside) {
  return `<div class="shot" data-blocks-theme="soft"><div class="shot__bar" aria-hidden="true"><i></i><i></i><i></i><span class="shot__address">handbook.example/release</span></div><div class="shot__page">
${above}
${inside}
${below}
</div></div>`;
}

function attempt(fn) {
  try {
    return { value: fn() };
  } catch (error) {
    return { error: error instanceof Error ? error.message : String(error) };
  }
}

function plate(feature, example) {
  const options = example.options ?? {};
  const before = String(example.before);
  const nodes = attempt(() => read(before, options));
  const given = nodes.error ?? write(nodes.value);
  const expected = example.error ?? String(example.after ?? "");
  const differs = example.error === undefined ? given.trimEnd() !== expected.trimEnd() : !given.includes(expected);
  const page =
    nodes.error === undefined
      ? shot(render(nodes.value, options))
      : `<div class="shot shot--failed"><p class="shot__failure">The build stops here.</p><pre class="shot__error">${escape(nodes.error)}</pre></div>`;
  return `<figure class="plate${differs ? " plate--differs" : ""}" id="${slug(feature)}-${slug(example.scenario)}">
<figcaption class="plate__head"><span class="plate__number"></span><span class="plate__title">${escape(example.scenario)}</span>${
    differs ? `<span class="plate__flag">Differs from the fixture</span>` : ""
  }</figcaption>
<div class="plate__grid">
<div class="plate__side plate__side--markdown"><p class="plate__label">Markdown</p><pre class="plate__source">${escape(before)}</pre></div>
<div class="plate__side plate__side--nodes"><p class="plate__label">${nodes.error === undefined ? "Nodes" : "Error"}</p><pre class="plate__source">${escape(given)}</pre>${
    differs ? `<p class="plate__label plate__label--expected">The fixture expects</p><pre class="plate__source">${escape(expected)}</pre>` : ""
  }</div>
<div class="plate__side plate__side--page"><p class="plate__label">Page</p>${page}</div>
</div>
</figure>`;
}

export function plates(name) {
  const fixture = name.trim();
  if (fixture === "") return "";
  const data = parse(readFileSync(new URL(`${fixture}.test.yaml`, fixtures), "utf8"));
  if (data.background?.given !== "a document") {
    throw new Error(`plates: ${fixture} is not a reader fixture (its given is "${data.background?.given}")`);
  }
  return `<div class="plates">\n${data.examples.map((example) => plate(data.feature, example)).join("\n")}\n</div>`;
}
