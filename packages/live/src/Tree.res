// A drawing of `@minidoc/blocks` as React elements. The DOM they make is
// the HTML that `Draw.write` gives for the same drawing, with no element
// added. A field draws as its text. Where the person edits, a text field
// draws in a span that holds the host's text field, or that a focus turns
// into a text area holding its source. A click field draws as a button,
// and an act draws with a click.

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

/** Where a host's text field puts the caret: at its start, its end, or an offset in the text as shown, without markup. */
@unboxed
type place = | @as("start") Start | @as("end") End | At(int)

/** A text cut at the caret by Enter, without the space at the cut. */
type cut = {before: string, after: string}

/** What a host's text field lets live do with it. */
type handle = {focus: place => unit}

/**
 * The props of a host's text field: a one-line editor of a text's
 * markdown. It hands on the whole text after each change, and never hands
 * on a text the person did not change. `onEnter` gives the text cut at the
 * caret, in markdown; with none, the caret is at the end.
 * `onBackspaceAtStart` comes with the caret at the start and no selection,
 * whatever the text holds. `onLeave` comes
 * when the field loses the focus, or on Escape.
 */
type textField = {
  markdown: string,
  onChange: string => unit,
  onEnter: option<cut> => unit,
  onBackspaceAtStart: unit => unit,
  onLeave: unit => unit,
  ref: Nullable.t<handle> => unit,
}

@module("react")
external hosted: (React.component<textField>, textField) => React.element = "createElement"

/**
 * Where the person edits a drawing: the field with the caret, by its key
 * and which of its drawings it is, from 0, where in it the caret goes when
 * it takes the focus, the text being written there, and what the person
 * does. With a host's text field, each text is drawn in it, and `handles`
 * keeps each field's handle.
 */
type editing = {
  caret: option<(string, int)>,
  at: place,
  draft: string,
  enters: (string, int, string) => unit,
  writes: (string, string) => unit,
  leaves: (string, int) => unit,
  acts: Draw.act => unit,
  field: option<React.component<textField>>,
  handles: ((string, int), Nullable.t<handle>) => unit,
  focuses: (string, int) => unit,
}

// A text with the caret picks the stage of a long plan it sits in: the
// radio button of its label.
let pick: {..} => unit = %raw(`(element) => {
  const radio = element.closest("label")?.querySelector("input[type=radio]");
  if (radio) radio.checked = true;
}`)

// The text area under the caret takes the focus once, with the caret at
// its start or its end, and picks its stage.
let focusing: (Nullable.t<Dom.element>, bool) => unit = %raw(`(element, start) => {
  if (element === null || element === undefined) return;
  if (element.getRootNode().activeElement === element) return;
  element.focus();
  const at = start ? 0 : element.value.length;
  element.setSelectionRange(at, at);
  const radio = element.closest("label")?.querySelector("input[type=radio]");
  if (radio) radio.checked = true;
}`)

@get external pressed: ReactEvent.Keyboard.t => string = "key"
// A key that an input method takes, such as the Enter that confirms a word
// typed in Japanese, is not the person's Enter.
let composing: ReactEvent.Keyboard.t => bool = %raw(`(event) => event.nativeEvent.isComposing || event.keyCode === 229`)
// The text area's draft cut at its selection, without the space at the cut.
let cutAt: ReactEvent.Keyboard.t => cut = %raw(`(event) => {
  const area = event.currentTarget;
  return {
    before: area.value.slice(0, area.selectionStart).trimEnd(),
    after: area.value.slice(area.selectionEnd).trimStart(),
  };
}`)
// Whether the focus leaves a text for the radio button of the label it sits in.
let toPick: ReactEvent.Focus.t => bool = %raw(`(event) => {
  const next = event.relatedTarget;
  return next?.type === "radio" && next.closest("label") === event.currentTarget.closest("label");
}`)
let focusBack: {..} => unit = %raw(`(element) => element.focus()`)
@send external blur: Dom.element => unit = "blur"
@get external currentTarget: ReactEvent.Keyboard.t => Dom.element = "currentTarget"

/** The key the act names, if any: what a drawn act is found by. */
let named = (act: Draw.act) =>
  switch act {
  | Write({key}) | SplitTodo({key}) => key
  | Tick(key) | MoveAlong(key) | AddTodoAfter(key) | AddTodoIn(key) | Remove(key) => key
  | AddStage => ""
  }

/** A drawing's parts, with what holds parts opened: many parts, and a field or an act unless the drawing is edited. An edited part shows only when the drawing is edited. */
let rec flat = (drawing: Draw.element, ~edited): array<Draw.element> =>
  switch drawing {
  | Many(items) => items->Array.flatMap(item => flat(item, ~edited))
  | Field({shown}) if !edited => flat(shown, ~edited)
  | Act(_) if !edited => []
  | Edited({shown}) => edited ? flat(shown, ~edited) : []
  | Nothing => []
  | Element(_) | Text(_) | Raw(_) | Field(_) | Act(_) => [drawing]
  }

let make = (~scope="", ~editing: option<editing>=?, drawing: Draw.element) => {
  let edited = editing->Option.isSome
  let seen = Dict.make()
  // Which drawing of its key a field is: a stage's title is drawn twice.
  let nth = key => {
    let n = seen->Dict.get(key)->Option.getOr(0)
    seen->Dict.set(key, n + 1)
    n
  }
  let scoped = attributes =>
    switch (scope, attributes->Dict.get("name")) {
    | ("", _) | (_, None) => attributes
    | (_, Some(JSON.String(name))) => {
        let copy = attributes->Dict.copy
        copy->Dict.set("name", JSON.String(`${scope}-${name}`))
        copy
      }
    | _ => attributes
    }
  let rec children = (parts: array<Draw.element>) =>
    parts->Array.flatMap(part =>
      switch part {
      | Element({tag, attributes, children: within}) =>
        switch within->Array.flatMap(item => flat(item, ~edited)) {
        | [Raw(html)] => [element(tag, inner(props(scoped(attributes)), html), [])]
        | parts => [element(tag, props(scoped(attributes)), children(parts))]
        }
      | Text(text) => [React.string(text)]
      | Raw(html) => raw(html)
      | Field({key, value, shown, input}) =>
        switch editing {
        | Some(editing) => [field(editing, key, value, shown, input)]
        | None => []
        }
      | Act({act, shown}) =>
        switch (editing, shown) {
        | (Some(editing), Element({tag, attributes, children: within})) => [
            element(
              tag,
              Object.assign(
                props(scoped(attributes)),
                {
                  "role": "button",
                  "tabIndex": 0,
                  "data-act": named(act),
                  "onClick": _ => editing.acts(act),
                },
              ),
              children(within->Array.flatMap(item => flat(item, ~edited))),
            ),
          ]
        | _ => []
        }
      | Many(_) | Edited(_) | Nothing => []
      }
    )
  and field = (editing, key, value, shown, input: Draw.input) => {
    let n = nth(key)
    let shown = children(flat(shown, ~edited))
    switch input {
    | Clicked(act) =>
      element(
        "button",
        {
          "type": "button",
          "className": "field field--click",
          "data-field": key,
          "value": value,
          "onClick": _ => editing.acts(act),
        },
        shown,
      )
    | Typed({enter, erase}) if editing.field->Option.isSome =>
      let under = editing.caret == Some((key, n))
      let text = under ? editing.draft : value
      element(
        "span",
        {
          "className": value == "" ? "field field--empty" : "field",
          "data-field": key,
          "onFocus": event => {
            event->ReactEvent.Focus.currentTarget->pick
            if !under {
              editing.enters(key, n, value)
            }
          },
          // A press beside the host's field, such as on an empty text's
          // hint, puts the caret at the field's end.
          "onMouseDown": event =>
            if event->ReactEvent.Mouse.target === event->ReactEvent.Mouse.currentTarget {
              event->ReactEvent.Mouse.preventDefault
              editing.focuses(key, n)
            },
          // A click on a text inside a long plan's label must not hand the
          // focus to the label's radio button.
          "onClick": ReactEvent.Mouse.preventDefault,
        },
        [
          hosted(
            editing.field->Option.getUnsafe,
            {
              markdown: text,
              onChange: next => editing.writes(key, next),
              onEnter: cut =>
                enter->Option.forEach(make => {
                  let {before, after} = cut->Option.getOr({before: text, after: ""})
                  editing.acts(make(before, after))
                }),
              onBackspaceAtStart: () =>
                if text == "" {
                  erase->Option.forEach(editing.acts)
                },
              onLeave: () => editing.leaves(key, n),
              ref: handle => editing.handles((key, n), handle),
            },
          ),
        ],
      )
    | Typed({enter, erase}) if editing.caret == Some((key, n)) =>
      element(
        "textarea",
        {
          "className": "field field--caret",
          "data-field": key,
          "value": editing.draft,
          "rows": 1,
          "spellCheck": false,
          "ref": element => focusing(element, editing.at == Start),
          "onChange": event => editing.writes(key, (event->ReactEvent.Form.target)["value"]),
          "onBlur": event =>
            if toPick(event) {
              // A click in a long plan's label hands the focus to its radio
              // button: the text keeps the caret.
              event->ReactEvent.Focus.currentTarget->focusBack
            } else {
              editing.leaves(key, n)
            },
          "onKeyDown": event =>
            switch (composing(event) ? "" : event->pressed, enter, erase) {
            | ("Enter", _, _) =>
              event->ReactEvent.Keyboard.preventDefault
              enter->Option.forEach(make => {
                let {before, after} = cutAt(event)
                editing.acts(make(before, after))
              })
            | ("Backspace", _, Some(act)) if editing.draft == "" =>
              event->ReactEvent.Keyboard.preventDefault
              editing.acts(act)
            | ("Escape", _, _) => event->currentTarget->blur
            | _ => ()
            },
        },
        [],
      )
    | Typed(_) =>
      element(
        "span",
        {
          "className": value == "" ? "field field--empty" : "field",
          "data-field": key,
          "tabIndex": 0,
          "onFocus": _ => editing.enters(key, n, value),
          // A click on a text inside a long plan's label must not hand the
          // focus to the label's radio button.
          "onClick": ReactEvent.Mouse.preventDefault,
        },
        shown,
      )
    }
  }
  fragment(fragmentType, Nullable.null, children(flat(drawing, ~edited)))
}
