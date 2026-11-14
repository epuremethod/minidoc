// A drawing of a block, made by the blocks' JSX: elements, text, the HTML
// markdown-it gives for prose, and fields. `write` writes it as HTML;
// `@minidoc/live` writes the same tree as React elements.
//
// Each file that draws names this module with `@@jsxConfig`, so a project
// that builds this package as a dependency, as maia does, may give it its
// own JSX, such as React's.

/** What the person does to a block. A field is named by its key. */
type act =
  | Write({key: string, text: string})
  | Tick(string)
  | MoveAlong(string)
  | AddTodoAfter(string)
  /** Enter in a todo: it keeps `before`, and a todo after it holds `after`. With no `after`, the todo stays as written. */
  | SplitTodo({key: string, before: string, after: string})
  | AddTodoIn(string)
  | AddStage
  | Remove(string)

/** How the person edits a field. */
type input =
  /**
   * Text written where it stands. Enter may carry an act, made from the
   * text before the caret and the text after it. Backspace in an empty
   * text may carry an act.
   */
  | Typed({enter: option<(string, string) => act>, erase: option<act>})
  /** A click carries an act. */
  | Clicked(act)

type rec element =
  | Element({tag: string, attributes: dict<JSON.t>, children: array<element>})
  | Text(string)
  /** HTML that markdown-it gives, for prose and inline markdown only. */
  | Raw(string)
  /** A value the person may edit: its key, its source text, how it shows, and how it is edited. */
  | Field({key: string, value: string, shown: element, input: input})
  /** A part drawn only where the person may edit, which carries an act, such as "+ stage". */
  | Act({act: act, shown: element})
  /** A part drawn only where the person may edit, which carries no act, such as an empty message's place. */
  | Edited({shown: element})
  | Many(array<element>)
  | Nothing

type componentLike<'props, 'return> = 'props => 'return
type component<'props> = componentLike<'props, element>
external component: componentLike<'props, element> => component<'props> = "%identity"

let jsx = (component: component<'props>, props: 'props) => component(props)
let jsxs = jsx
let jsxKeyed = (component: component<'props>, props: 'props, ~key as _: option<string>=?, ()) =>
  component(props)
let jsxsKeyed = jsxKeyed

type fragmentProps = {children?: element}
let jsxFragment = (props: fragmentProps) => props.children->Option.getOr(Nothing)

let null = Nothing
let string = text => Text(text)
let array = items => Many(items)
let raw = html => Raw(html)
let field = (~key, ~value, ~input=Typed({enter: None, erase: None}), shown) => Field({
  key,
  value,
  shown,
  input,
})
let act = (act, shown) => Act({act, shown})
let edited = shown => Edited({shown: shown})

module Elements = {
  // The attributes the blocks write, each named as in HTML. ReScript writes
  // a record's keys in the order this type declares them, and that is the
  // order of the attributes in the HTML.
  type props = {
    @as("class") className?: string,
    id?: string,
    href?: string,
    style?: string,
    @as("type") type_?: string,
    name?: string,
    @as("datetime") dateTime?: string,
    checked?: bool,
    viewBox?: string,
    refX?: string,
    refY?: string,
    markerWidth?: string,
    markerHeight?: string,
    markerUnits?: string,
    orient?: string,
    @as("marker-start") markerStart?: string,
    @as("marker-end") markerEnd?: string,
    d?: string,
    x?: string,
    y?: string,
    x1?: string,
    y1?: string,
    x2?: string,
    y2?: string,
    cx?: string,
    cy?: string,
    r?: string,
    width?: string,
    height?: string,
    rx?: string,
    @as("text-anchor") textAnchor?: string,
    role?: string,
    @as("aria-label") ariaLabel?: string,
    @as("aria-hidden") ariaHidden?: string,
    @as("data-step") dataStep?: string,
    @as("data-move") dataMove?: string,
    @as("data-ends") dataEnds?: string,
    @as("data-parent") dataParent?: string,
    @as("data-process") dataProcess?: string,
    children?: element,
  }

  let attributes: props => dict<JSON.t> = %raw(`(props) => {
    const out = {};
    for (const [name, value] of Object.entries(props)) {
      if (name !== "children" && value !== undefined && value !== false) out[name] = value;
    }
    return out;
  }`)

  let jsx = (tag: string, props: props) => Element({
    tag,
    attributes: attributes(props),
    children: switch props.children {
    | None | Some(Nothing) => []
    | Some(Many(items)) => items
    | Some(child) => [child]
    },
  })
  let jsxs = jsx
  let jsxKeyed = (tag, props, ~key as _: option<string>=?, ()) => jsx(tag, props)
  let jsxsKeyed = jsxKeyed
  external someElement: element => option<element> = "%identity"
}

/** SVG elements written as `<path … />` when they have no children. */
let leaves = ["path", "line", "rect", "circle"]

/** HTML elements that never close. */
let voids = ["input", "br", "hr", "img"]

let attribute = ((name, value): (string, JSON.t)) =>
  switch value {
  | Boolean(true) => ` ${name}`
  | String(text) => ` ${name}="${Html.escape(text)}"`
  | _ => ""
  }

/** The HTML of a drawing. A field is written as it shows, and an act or an edited part not at all. */
let rec write = element =>
  switch element {
  | Element({tag, attributes, children}) =>
    let opening = attributes->Dict.toArray->Array.map(attribute)->Array.join("")
    if children == [] && leaves->Array.includes(tag) {
      `<${tag}${opening} />`
    } else if voids->Array.includes(tag) {
      `<${tag}${opening}>`
    } else {
      `<${tag}${opening}>${children->Array.map(write)->Array.join("")}</${tag}>`
    }
  | Text(text) => Html.escape(text)
  | Raw(html) => html
  | Field({shown}) => write(shown)
  | Many(items) => items->Array.map(write)->Array.join("")
  | Act(_) | Edited(_) | Nothing => ""
  }

/** The fields of a drawing, each key once, in the order they are drawn. */
let fields = element => {
  let found = []
  let rec walk = element =>
    switch element {
    | Element({children}) | Many(children) => children->Array.forEach(walk)
    | Edited({shown}) => walk(shown)
    | Field({key, value}) =>
      if !(found->Array.some(((k, _)) => k == key)) {
        found->Array.push((key, value))
      }
    | Text(_) | Raw(_) | Act(_) | Nothing => ()
    }
  walk(element)
  found
}

/** Items with `between` written between each two. */
let joined = (items: array<element>, between: string) => Many(
  items->Array.flatMapWithIndex((item, index) => index == 0 ? [item] : [Text(between), item]),
)

/** The drawing with `prefix` before each of its fields' keys. */
let rec under = (element, prefix) =>
  switch element {
  | Element(e) => Element({...e, children: e.children->Array.map(child => under(child, prefix))})
  | Field(f) => Field({...f, key: prefix ++ f.key})
  | Many(items) => Many(items->Array.map(item => under(item, prefix)))
  | Edited({shown}) => Edited({shown: under(shown, prefix)})
  | Text(_) | Raw(_) | Act(_) | Nothing => element
  }
