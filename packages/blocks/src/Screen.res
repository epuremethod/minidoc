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

@@jsxConfig({version: 4, module_: "Draw"})

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
let text = Draw.string
let nl = Draw.string("\n")

let draw = (~form=false, md, owner, title, widgets) => {
  let inline = (key, source) =>
    Draw.field(~key, ~value=source, Draw.raw(Markdown.renderInline(md, source, Markdown.env())))
  let plain = (key, value) => Draw.field(~key, ~value, text(value))
  let button = (b: button, ~key) =>
    <span
      className={`ui-dialog__button${b.primary ? " ui-dialog__button--primary" : ""}${b.clicked
          ? " ui-dialog__button--clicked"
          : ""}`}
    >
      {plain(key, b.text)}
    </span>
  let buttons = (list, ~at) =>
    list
    ->Array.mapWithIndex((b, i) => button(b, ~key=`${at} button ${Int.toString(i + 1)}`))
    ->Draw.array
  let part = (w, index) => {
    let at = `widget ${Int.toString(index + 1)}`
    switch w {
    | Text(source) => Draw.raw(Markdown.render(md, source, Markdown.env()))
    | Actions(list) =>
      <>
        <div className="ui-dialog__actions"> {buttons(list, ~at)} </div>
        nl
      </>
    | Options(choices) =>
      <>
        <div className="ui-dialog__options">
          {choices
          ->Array.mapWithIndex((c, i) =>
            <div
              className={`ui-dialog__option ui-dialog__option--${c.radio ? "radio" : "check"}${c.on
                  ? " ui-dialog__option--on"
                  : ""}`}
            >
              {inline(`${at} option ${Int.toString(i + 1)}`, c.text)}
            </div>
          )
          ->Draw.array}
        </div>
        nl
      </>
    | Field({label, value, select, buttons: list}) =>
      let input =
        <span className={`ui-dialog__input${select ? " ui-dialog__input--select" : ""}`}>
          {plain(`${at} value`, value->Option.getOr(""))}
        </span>
      <>
        <div className="ui-dialog__field">
          <span className="ui-dialog__field-label"> {inline(`${at} label`, label)} </span>
          {list == []
            ? input
            : <span className="ui-dialog__control">
                input
                {buttons(list, ~at)}
              </span>}
        </div>
        nl
      </>
    }
  }
  let kind = form ? "Form mockup" : "Screen mockup"
  let className = `ui-dialog${form ? " ui-form" : ""}${owner->Option.mapOr("", ((key, _)) =>
      ` ui-dialog--${key}`
    )}`
  let style = owner->Option.map(((key, _)) => `--tone: var(--tone-${key}, var(--blocks-ink))`)
  let bar =
    [
      owner->Option.map(((_, label)) => <span className="ui-dialog__owner"> {text(label)} </span>),
      title->Option.map(t => <span className="ui-dialog__title"> {plain("title", t)} </span>),
    ]->Array.keepSome
  <>
    <div className ?style role="group" ariaLabel={title->Option.mapOr(kind, t => `${kind}: ${t}`)}>
      {bar == [] ? Draw.null : <div className="ui-dialog__bar"> {Draw.array(bar)} </div>}
      <div className="ui-dialog__body">
        nl
        {widgets->Array.mapWithIndex(part)->Draw.array}
      </div>
    </div>
    nl
  </>
}

/** A flow of screens: its caption, then the screens drawn by `inner`. */
let drawFlow = (caption, inner) => <>
  <figure className="ui-flow">
    {switch caption {
    | Some(c) => <figcaption className="ui-flow__caption"> {text(c)} </figcaption>
    | None => Draw.null
    }}
    <div className="ui-flow__steps">
      nl
      inner
    </div>
  </figure>
  nl
</>
