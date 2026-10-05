// A screen mockup. `::: ui-dialog owner Title` opens a screen: the owner,
// optional, says who presents it. `::: ui-form owner Title` is a wider
// screen whose fields line up, label beside input. `:::: ui-flow Caption`
// holds screens in the order the person sees them. Ported from SWISSID's
// scripts/ui-dialog.mjs.
//
// A screen's body is markdown. Some lines are drawn:
//
//   [Cancel] [[Continue]]   buttons; double brackets mark the primary one
//   [VS-ID]*                the button the person clicks
//   ( ) No   (x) Yes        radio buttons
//   [ ] No   [x] Yes        checkboxes
//   Password : ____         an input field
//   Name : "Sion"           a field showing a value
//   Format : "JSON" ▾       a list to pick from
//   Token : "a1b2" [Copy]   buttons beside a field

open Node

let buttonLine = RegExp.fromString("^(?:(?:\\[\\[[^\\[\\]]+\\]\\]|\\[[^\\[\\]]+\\])\\*?\\s*)+$")
let optionLine = RegExp.fromString("^(\\( \\)|\\(x\\)|\\[ \\]|\\[x\\])\\s+(\\S.*)$", ~flags="i")
let fieldLine = RegExp.fromString(
  "^(\\S.*?)\\s*:\\s*(?:_{3,}|\"([^\"]*)\"(\\s*▾)?)((?:\\s*\\[[^\\[\\]]+\\]\\*?)*)$",
)
let blankLine = RegExp.fromString("\\n[ \\t]*\\n")

let buttons: string => array<button> = %raw(`(line) =>
  [...line.matchAll(/\[\[([^\[\]]+)\]\](\*?)|\[([^\[\]]+)\](\*?)/g)].map(
    ([, primary, primaryClick, plain, plainClick]) => ({
      text: (primary ?? plain).trim(),
      primary: primary !== undefined,
      clicked: Boolean(primaryClick || plainClick),
    }),
  )`)

let capture = Sequence.capture

let widget = line =>
  RegExp.test(buttonLine, line) || RegExp.test(optionLine, line) || RegExp.test(fieldLine, line)

// The widgets of one paragraph, or its text when it holds none.
let paragraph = source => {
  let lines = source->String.split("\n")->Array.map(String.trim)
  if !(lines->Array.some(widget)) {
    [Text(source)]
  } else {
    let parts = []
    let text = []
    let options = []
    let flush = () => {
      if text != [] {
        parts->Array.push(Text(text->Array.join("\n")))
      }
      if options != [] {
        parts->Array.push(Options(Array.copy(options)))
      }
      text->Array.splice(~start=0, ~remove=Array.length(text), ~insert=[])
      options->Array.splice(~start=0, ~remove=Array.length(options), ~insert=[])
    }
    lines->Array.forEach(line =>
      if RegExp.test(buttonLine, line) {
        flush()
        parts->Array.push(Actions(buttons(line)))
      } else {
        switch (RegExp.exec(optionLine, line), RegExp.exec(fieldLine, line)) {
        | (Some(m), _) =>
          if text != [] {
            flush()
          }
          let mark = capture(m, 0)->Option.getOr("")
          options->Array.push({
            text: capture(m, 1)->Option.getOr(""),
            radio: String.startsWith(mark, "("),
            on: String.toLowerCase(String.charAt(mark, 1)) == "x",
          })
        | (None, Some(m)) =>
          flush()
          parts->Array.push(
            Field({
              label: capture(m, 0)->Option.getOr(""),
              value: capture(m, 1),
              select: capture(m, 2)->Option.isSome,
              buttons: buttons(capture(m, 3)->Option.getOr("")),
            }),
          )
        | (None, None) =>
          if options != [] {
            flush()
          }
          text->Array.push(line)
        }
      }
    )
    flush()
    parts
  }
}

let read = (info, body, owners: dict<string>) => {
  let (first, rest) = Scan.split(info)
  let (owner, title) = switch owners->Dict.get(first) {
  | Some(label) => (Some((first, label)), rest)
  | None => (None, info)
  }
  let widgets =
    body
    ->String.splitByRegExp(blankLine)
    ->Array.filterMap(p => p)
    ->Array.filter(p => String.trim(p) != "")
    ->Array.flatMap(p => paragraph(String.trim(p)))
  (owner, title == "" ? None : Some(title), widgets)
}

// A form is a screen too: it shares the dialog's parts and adds `ui-form`.
let render = (~form=false, md, owner, title, widgets) => {
  let escape = Html.escape
  let inline = text => Markdown.renderInline(md, text, Markdown.env())
  let button = (b: button) =>
    `<span class="ui-dialog__button${b.primary ? " ui-dialog__button--primary" : ""}${b.clicked
        ? " ui-dialog__button--clicked"
        : ""}">${escape(b.text)}</span>`
  let part = w =>
    switch w {
    | Text(text) => Markdown.render(md, text, Markdown.env())
    | Actions(buttons) =>
      `<div class="ui-dialog__actions">${buttons->Array.map(button)->Array.join("")}</div>\n`
    | Options(choices) =>
      let row = choices->Array.map(c =>
        `<div class="ui-dialog__option ui-dialog__option--${c.radio ? "radio" : "check"}${c.on
            ? " ui-dialog__option--on"
            : ""}">${inline(c.text)}</div>`
      )
      `<div class="ui-dialog__options">${row->Array.join("")}</div>\n`
    | Field({label, value, select, buttons}) =>
      let input = `<span class="ui-dialog__input${select ? " ui-dialog__input--select" : ""}">${value->Option.mapOr("", escape)}</span>`
      let control = buttons == []
        ? input
        : `<span class="ui-dialog__control">${input}${buttons->Array.map(button)->Array.join("")}</span>`
      `<div class="ui-dialog__field"><span class="ui-dialog__field-label">${inline(label)}</span>${control}</div>\n`
    }
  let kind = form ? "Form mockup" : "Screen mockup"
  let label = title->Option.mapOr(kind, t => `${kind}: ${t}`)
  let bar = [
    owner->Option.map(((_, label)) => `<span class="ui-dialog__owner">${escape(label)}</span>`),
    title->Option.map(t => `<span class="ui-dialog__title">${escape(t)}</span>`),
  ]->Array.keepSome->Array.join("")
  `<div class="ui-dialog${form ? " ui-form" : ""}${owner->Option.mapOr("", ((key, _)) =>
      ` ui-dialog--${key}" style="--tone: var(--tone-${key}, var(--blocks-ink))`
    )}" role="group" aria-label="${escape(label)}">${bar == ""
      ? ""
      : `<div class="ui-dialog__bar">${bar}</div>`}<div class="ui-dialog__body">\n${widgets
    ->Array.map(part)
    ->Array.join("")}</div></div>\n`
}

let renderFlow = (caption, inner) =>
  `<figure class="ui-flow">${caption->Option.mapOr("", c =>
      `<figcaption class="ui-flow__caption">${Html.escape(c)}</figcaption>`
    )}<div class="ui-flow__steps">\n${inner}</div></figure>\n`
