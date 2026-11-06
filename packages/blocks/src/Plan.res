// The `plan` block: a numbered list whose top items are stages, each
// starting with its mark, `[x]` done, `[/]` in progress or `[ ]` not
// started, then its bold title and a message. The bullets under a stage are
// its todos, `[x]` or `[ ]`. A bullet list alone is todos only.

@@jsxConfig({version: 4, module_: "Draw"})

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

let text = Draw.string
let nl = Draw.string("\n")

let draw = (md, title, stages, todos, ~name) => {
  let inline = (key, source) =>
    Draw.field(~key, ~value=source, Draw.raw(Markdown.renderInline(md, source, Markdown.env())))
  let stageKey = index => `stage ${Int.toString(index + 1)}`
  let number = index => <span className="plan__number"> {text(Int.toString(index + 1))} </span>
  let list = (todos, ~at) => <>
    <ul className="plan__list">
      nl
      {todos
      ->Array.mapWithIndex((t, i) =>
        <li className={`plan__todo${t.done ? " plan__todo--done" : ""}`}>
          {inline(`${at}todo ${Int.toString(i + 1)}`, t.text)}
        </li>
      )
      ->Draw.joined("\n")}
      nl
    </ul>
    nl
  </>
  let state = (index, s) => {
    let done = s.todos->Array.filter(t => t.done)->Array.length
    <>
      {number(index)}
      {switch s.message {
      | Some(m) =>
        <span className="plan__message"> {inline(`${stageKey(index)} message`, m)} </span>
      | None => Draw.null
      }}
      {s.todos == []
        ? Draw.null
        : <span className="plan__count">
            {text(`${Int.toString(done)}/${Int.toString(Array.length(s.todos))}`)}
          </span>}
    </>
  }
  let name' = (index, s) => inline(`${stageKey(index)} title`, s.title)
  let stageItem = (index, s) =>
    <li className={`plan__stage${modifier("plan__stage", s.state)}`}>
      <p className="plan__state"> {state(index, s)} </p>
      <p className="plan__name"> {name'(index, s)} </p>
    </li>
  let heading = (index, s) => <>
    <p className="plan__heading">
      {number(index)}
      {text(" ")}
      {name'(index, s)}
    </p>
    nl
  </>
  let todosOf = (index, s) => list(s.todos, ~at=`${stageKey(index)} `)
  let group = (index, s) =>
    s.todos == []
      ? None
      : Some(
          <section className={`plan__group${modifier("plan__group", s.state)}`}>
            {heading(index, s)}
            {todosOf(index, s)}
          </section>,
        )
  let first = shown(stages)
  let pick = (index, s) =>
    <li className="plan__item">
      <label className={`plan__stage${modifier("plan__stage", s.state)}`}>
        <input className="plan__pick" type_="radio" name checked={index == first} />
        <span className="plan__state"> {state(index, s)} </span>
        <span className="plan__name"> {name'(index, s)} </span>
      </label>
      nl
      <section className={`plan__group${modifier("plan__group", s.state)}`}>
        {heading(index, s)}
        {s.todos == [] ? Draw.null : todosOf(index, s)}
      </section>
    </li>
  let groups = stages->Array.mapWithIndex((s, i) => group(i, s))->Array.keepSome
  let body = if stages == [] {
    list(todos, ~at="")
  } else if long(stages) {
    <>
      <ol className="plan__stages" style={`--plan-rows: ${Int.toString(Array.length(stages))}`}>
        nl
        {stages->Array.mapWithIndex((s, i) => pick(i, s))->Draw.joined("\n")}
        nl
      </ol>
      nl
    </>
  } else {
    <>
      <ol className="plan__stages">
        nl
        {stages->Array.mapWithIndex((s, i) => stageItem(i, s))->Draw.joined("\n")}
        nl
      </ol>
      nl
      {groups == []
        ? Draw.null
        : <>
            <div className="plan__todos">
              nl
              {groups->Draw.joined("\n")}
              nl
            </div>
            nl
          </>}
    </>
  }
  <>
    <figure className={`plan${long(stages) ? " plan--long" : ""}`}>
      {switch title {
      | Some(t) =>
        <>
          <figcaption className="plan__title"> {inline("title", t)} </figcaption>
          nl
        </>
      | None => nl
      }}
      body
    </figure>
    nl
  </>
}
