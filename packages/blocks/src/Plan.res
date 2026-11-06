// The `plan` block: a numbered list whose top items are stages, each
// starting with its mark, `[x]` done, `[/]` in progress or `[ ]` not
// started, then its bold title and a message. The bullets under a stage are
// its todos, `[x]` or `[ ]`. A bullet list alone is todos only.

open Node

let mark = RegExp.fromString("^\\[([ xX/])\\]\\s+(\\S.*)$")
let titled = RegExp.fromString("^(?:\\*\\*(.+?)\\*\\*|__(.+?)__)(?:\\s+(\\S.*))?$")

let at = (line, item: Flow.item) => Int.toString(line + 1 + item.line)
let text = (item: Flow.item) => item.text->Option.getOr("")

// The mark and the rest of an item's first line.
let marked = item =>
  RegExp.exec(mark, text(item))->Option.map(m => (Scan.capture(m, 0), Scan.capture(m, 1)))

let todo = (line, item) =>
  switch marked(item) {
  | Some(("x" | "X", rest)) => {text: rest, done: true}
  | Some((" ", rest)) => {text: rest, done: false}
  | _ => Html.fail(`plan: a todo starts with [x] or [ ], line ${at(line, item)}: ${text(item)}`)
  }

let stage = (line, item: Flow.item) => {
  let (state, rest) = switch marked(item) {
  | Some(("x" | "X", rest)) => (Done, rest)
  | Some(("/", rest)) => (Doing, rest)
  | Some((_, rest)) => (NotStarted, rest)
  | None => Html.fail(`plan: a stage starts with [x], [/] or [ ], line ${at(line, item)}: ${text(item)}`)
  }
  let (title, message) = switch RegExp.exec(titled, rest) {
  | Some(m) =>
    let parts = m->RegExp.Result.matches
    let bold = [parts->Array.get(0), parts->Array.get(1)]->Array.filterMap(p => p->Option.flatMap(x => x))
    (bold->Array.get(0)->Option.getOr(rest), parts->Array.get(2)->Option.flatMap(x => x))
  | None => (rest, None)
  }
  let items = item.lists->Array.get(0)->Option.mapOr([], l => l.items)
  let todos = items->Array.map(i => todo(line, i))
  if state == Done {
    items->Array.forEach(i =>
      if !todo(line, i).done {
        Html.fail(`plan: an open todo in a done stage, line ${at(line, i)}: ${todo(line, i).text}`)
      }
    )
  }
  {state, title, message, todos}
}

let read = (md, info, body, line) => {
  let title = String.trim(info) == "" ? None : Some(String.trim(info))
  switch Flow.lists(md, body)->Array.get(0) {
  | Some({ordered: true, items}) => Plan({title, stages: items->Array.map(i => stage(line, i)), todos: []})
  | Some({ordered: false, items}) => Plan({title, stages: [], todos: items->Array.map(i => todo(line, i))})
  | None =>
    Html.fail(`plan: a plan is a numbered list of stages or a bullet list of todos, line ${Int.toString(line)}`)
  }
}

let stateName = state =>
  switch state {
  | Done => Some("done")
  | Doing => Some("doing")
  | NotStarted => None
  }

let modifier = (block, state) => stateName(state)->Option.mapOr("", s => ` ${block}--${s}`)

/** A plan of more than four stages draws them one under the other, with the todos of one stage beside them. */
let long = stages => Array.length(stages) > 4

// The stage a long plan shows first: the one in progress, else the first
// not started, else the last.
let shown = stages =>
  switch stages->Array.findIndex(s => s.state == Doing) {
  | -1 =>
    switch stages->Array.findIndex(s => s.state == NotStarted) {
    | -1 => Array.length(stages) - 1
    | index => index
    }
  | index => index
  }

let render = (md, title, stages, todos, ~name) => {
  let inline = text => Markdown.renderInline(md, text, Markdown.env())
  let number = index => `<span class="plan__number">${Int.toString(index + 1)}</span>`
  let list = todos =>
    `<ul class="plan__list">\n${todos
      ->Array.map(t => `<li class="plan__todo${t.done ? " plan__todo--done" : ""}">${inline(t.text)}</li>`)
      ->Array.join("\n")}\n</ul>\n`
  let state = (index, s) => {
    let message = s.message->Option.mapOr("", m => `<span class="plan__message">${inline(m)}</span>`)
    let done = s.todos->Array.filter(t => t.done)->Array.length
    let count =
      s.todos == []
        ? ""
        : `<span class="plan__count">${Int.toString(done)}/${Int.toString(Array.length(s.todos))}</span>`
    `${number(index)}${message}${count}`
  }
  let stageItem = (index, s) =>
    `<li class="plan__stage${modifier("plan__stage", s.state)}"><p class="plan__state">${state(
        index,
        s,
      )}</p><p class="plan__name">${inline(s.title)}</p></li>`
  let heading = (index, s) => `<p class="plan__heading">${number(index)} ${inline(s.title)}</p>\n`
  let group = (index, s) =>
    s.todos == []
      ? None
      : Some(`<section class="plan__group${modifier("plan__group", s.state)}">${heading(index, s)}${list(s.todos)}</section>`)
  let first = shown(stages)
  let pick = (index, s) =>
    `<li class="plan__item"><label class="plan__stage${modifier(
        "plan__stage",
        s.state,
      )}"><input class="plan__pick" type="radio" name="${name}"${index == first
        ? " checked"
        : ""}><span class="plan__state">${state(index, s)}</span><span class="plan__name">${inline(
        s.title,
      )}</span></label>\n<section class="plan__group${modifier("plan__group", s.state)}">${heading(
        index,
        s,
      )}${s.todos == [] ? "" : list(s.todos)}</section></li>`
  let caption = title->Option.mapOr("", t => `<figcaption class="plan__title">${inline(t)}</figcaption>\n`)
  let groups = stages->Array.mapWithIndex((s, i) => group(i, s))->Array.keepSome
  let body = if stages == [] {
    list(todos)
  } else if long(stages) {
    `<ol class="plan__stages" style="--plan-rows: ${Int.toString(Array.length(stages))}">\n${stages
      ->Array.mapWithIndex((s, i) => pick(i, s))
      ->Array.join("\n")}\n</ol>\n`
  } else {
    `<ol class="plan__stages">\n${stages
      ->Array.mapWithIndex((s, i) => stageItem(i, s))
      ->Array.join("\n")}\n</ol>\n${groups == []
        ? ""
        : `<div class="plan__todos">\n${groups->Array.join("\n")}\n</div>\n`}`
  }
  `<figure class="plan${long(stages) ? " plan--long" : ""}">${caption == "" ? "\n" : caption}${body}</figure>\n`
}
