// A drawing of `@minidoc/blocks` as React elements. The DOM they make is
// the HTML that `Draw.write` gives for the same drawing, with no element
// added. A field draws as its text.

module Draw = MinidocBlocks.Draw

@module("react") @variadic
external element: (string, {..}, array<React.element>) => React.element = "createElement"
@module("react") @variadic
external fragment: (React.component<{.}>, Nullable.t<{.}>, array<React.element>) => React.element =
  "createElement"
@module("react") external fragmentType: React.component<{.}> = "Fragment"

// React's name for an attribute named as in HTML: `className` for `class`,
// `textAnchor` for `text-anchor`, a style as an object, and `defaultChecked`
// for `checked`, which the person may change.
let props: dict<JSON.t> => {..} = %raw(`(attributes) => {
  const props = {};
  for (const [name, value] of Object.entries(attributes)) {
    if (name === "class") props.className = value;
    else if (name === "for") props.htmlFor = value;
    else if (name === "checked") props.defaultChecked = value;
    else if (name === "style") {
      const style = {};
      for (const rule of String(value).split(";")) {
        const at = rule.indexOf(":");
        if (at > 0) style[rule.slice(0, at).trim()] = rule.slice(at + 1).trim();
      }
      props.style = style;
    } else if (name.includes("-") && !name.startsWith("aria-") && !name.startsWith("data-")) {
      props[name.replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = value;
    } else props[name] = value;
  }
  return props;
}`)

let inner = (props, html) => Object.assign(props, {"dangerouslySetInnerHTML": {"__html": html}})

// HTML beside other children, split into its top-level nodes by the
// browser's own parser. Each element keeps its tag and attributes, and
// takes its own inner HTML.
let split: (
  string,
  (string, dict<JSON.t>, string) => React.element,
) => array<React.element> = %raw(`(html, make) => {
  const template = document.createElement("template");
  template.innerHTML = html;
  return [...template.content.childNodes].flatMap((node) => {
    if (node.nodeType === 3) return [node.textContent];
    if (node.nodeType !== 1) return [];
    const attributes = {};
    for (const a of node.attributes) attributes[a.name] = a.value;
    return [make(node.localName, attributes, node.innerHTML)];
  });
}`)

let raw = html =>
  split(html, (tag, attributes, html) =>
    element(tag, html == "" ? props(attributes) : inner(props(attributes), html), [])
  )

/** A drawing's parts, with what holds parts opened: many parts, a field. */
let rec flat = (drawing: Draw.element): array<Draw.element> =>
  switch drawing {
  | Many(items) => items->Array.flatMap(flat)
  | Field({shown}) => flat(shown)
  | Nothing => []
  | Element(_) | Text(_) | Raw(_) => [drawing]
  }

let rec children = (parts: array<Draw.element>) =>
  parts->Array.flatMap(part =>
    switch part {
    | Element({tag, attributes, children: within}) =>
      switch within->Array.flatMap(flat) {
      | [Raw(html)] => [element(tag, inner(props(attributes), html), [])]
      | parts => [element(tag, props(attributes), children(parts))]
      }
    | Text(text) => [React.string(text)]
    | Raw(html) => raw(html)
    | Many(_) | Field(_) | Nothing => []
    }
  )

/** The React elements of a drawing. */
let make = (drawing: Draw.element) => fragment(fragmentType, Nullable.null, children(flat(drawing)))
