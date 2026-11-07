// The `plan` block: a numbered list whose top items are stages, each
// starting with its mark, `[x]` done, `[/]` in progress or `[ ]` not
// started, then its bold title and a message. The bullets under a stage are
// its todos, `[x]` or `[ ]`. A bullet list alone is todos only. A stage or
// a todo may have no text yet, and `****` is an empty bold title.

@@jsxConfig({version: 4, module_: "Draw"})

open Node

let mark = RegExp.fromString("^\\[([ xX/])\\](?:\\s+(\\S.*))?$")
let titled = RegExp.fromString("^(?:\\*\\*(.*?)\\*\\*|__(.*?)__)(?:\\s+(\\S.*))?$")

let at = (line, item: Flow.item) => line + 1 + item.line
let text = (item: Flow.item) => item.text->Option.getOr("")

// The mark and the rest of an item's first line.
let marked = item =>
  RegExp.exec(mark, text(item))->Option.map(m => (Scan.capture(m, 0), Scan.capture(m, 1)))

let todo = (line, item) =>
  switch marked(item) {
  | Some(("x" | "X", rest)) => {text: rest, done: true, line: at(line, item)}
  | Some((" ", rest)) => {text: rest, done: false, line: at(line, item)}
  | _ =>
    Html.fail(
      `plan: a todo starts with [x] or [ ], line ${Int.toString(at(line, item))}: ${text(item)}`,
    )
  }

let stage = (line, item: Flow.item) => {
  let (state, rest) = switch marked(item) {
  | Some(("x" | "X", rest)) => (Done, rest)
  | Some(("/", rest)) => (Doing, rest)
  | Some((_, rest)) => (NotStarted, rest)
  | None =>
    Html.fail(
      `plan: a stage starts with [x], [/] or [ ], line ${Int.toString(at(line, item))}: ${text(
          item,
        )}`,
    )
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
    todos->Array.forEach(t =>
      if !t.done {
        Html.fail(`plan: an open todo in a done stage, line ${Int.toString(t.line)}: ${t.text}`)
      }
    )
  }
  {state, title, message, todos, line: at(line, item)}
}

let read = (md, info, body, line) => {
  let title = String.trim(info) == "" ? None : Some(String.trim(info))
  switch Flow.lists(md, body)->Array.get(0) {
  | Some({ordered: true, items}) =>
    Plan({title, stages: items->Array.map(i => stage(line, i)), todos: [], line})
  | Some({ordered: false, items}) =>
    Plan({title, stages: [], todos: items->Array.map(i => todo(line, i)), line})
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
  let inline = (~input=?, key, source) =>
    Draw.field(~key, ~value=source, ~input?, Draw.raw(Markdown.renderInline(md, source, Markdown.env())))
  let stageKey = index => `stage ${Int.toString(index + 1)}`
  let number = index => <span className="plan__number"> {text(Int.toString(index + 1))} </span>
  let markOf = done => done ? "[x]" : "[ ]"
  let stageMark = s =>
    switch s.state {
    | Done => "[x]"
    | Doing => "[/]"
    | NotStarted => "[ ]"
    }
  let list = (todos, ~at) => <>
    <ul className="plan__list">
      nl
      {todos
      ->Array.mapWithIndex((t, i) => {
        let key = `${at}todo ${Int.toString(i + 1)}`
        <li className={`plan__todo${t.done ? " plan__todo--done" : ""}`}>
          {Draw.field(~key=`${key} mark`, ~value=markOf(t.done), ~input=Clicked(Tick(key)), Draw.null)}
          {inline(
            ~input=Typed({
              enter: Some((before, after) => SplitTodo({key, before, after})),
              erase: Some(Remove(key)),
            }),
            key,
            t.text,
          )}
        </li>
      })
      ->Draw.joined("\n")}
      nl
    </ul>
    nl
  </>
  let name' = (index, s) =>
    inline(
      ~input=Typed({enter: None, erase: s.todos == [] ? Some(Remove(stageKey(index))) : None}),
      `${stageKey(index)} title`,
      s.title,
    )
  // Line 1 holds the number and the title, and the stage's state drawn
  // after them by CSS; the message follows on a line of its own. An empty
  // message is drawn only where the person may edit, in the same span as a
  // written one, so the first letter written does not move its field.
  let line = (index, s) =>
    <span className="plan__line">
      {Draw.field(
        ~key=`${stageKey(index)} mark`,
        ~value=stageMark(s),
        ~input=Clicked(MoveAlong(stageKey(index))),
        number(index),
      )}
      {text(" ")}
      <span className="plan__name"> {name'(index, s)} </span>
    </span>
  let message = (index, s) => {
    let key = `${stageKey(index)} message`
    switch s.message {
    | Some(m) => <span className="plan__message"> {inline(key, m)} </span>
    | None => Draw.edited(<span className="plan__message"> {inline(key, "")} </span>)
    }
  }
  let addTodo = (index, s) =>
    s.todos == []
      ? Draw.act(AddTodoIn(stageKey(index)), <p className="plan__add"> {text("+ todo")} </p>)
      : Draw.null
  let stageItem = (index, s) =>
    <li className={`plan__stage${modifier("plan__stage", s.state)}`}>
      {line(index, s)}
      {message(index, s)}
      {addTodo(index, s)}
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
        {line(index, s)}
        {message(index, s)}
      </label>
      nl
      <section className={`plan__group${modifier("plan__group", s.state)}`}>
        {heading(index, s)}
        {s.todos == [] ? addTodo(index, s) : todosOf(index, s)}
      </section>
    </li>
  let addStage = Draw.act(AddStage, <p className="plan__add"> {text("+ stage")} </p>)
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
      addStage
    </>
  } else {
    <>
      <ol className="plan__stages">
        nl
        {stages->Array.mapWithIndex((s, i) => stageItem(i, s))->Draw.joined("\n")}
        nl
      </ol>
      nl
      addStage
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
      | None => <> {inline("title", "")} nl </>
      }}
      body
    </figure>
    nl
  </>
}

// ── Edits ────────────────────────────────────────────────────────────────
//
// An edit reads the line of the stage or the todo again, with the parts
// the reader saw, and changes only the characters of the part it names.
// Lines count from 1 in the page.

/** A source with an act applied, and the field the caret goes to; `None` leaves the caret where it is. */
type edited = {source: string, caret: option<string>}

let stageLine = RegExp.fromString("^(\\s*)(\\d+)([.)])(\\s+)\\[([ xX/])\\](.*)$")
let todoLine = RegExp.fromString("^(\\s*)([-*+])(\\s+)\\[([ xX])\\](.*)$")
let openingLine = RegExp.fromString("^(\\s*:{3,}\\s*plan)(\\s*)(.*)$")
let spaced = RegExp.fromString("^(\\s*)(.*)$")
let boldWords = RegExp.fromString("^(\\*\\*|__)(.*?)\\1(?:(\\s+)(\\S.*))?$")

// A line of a stage or a todo, cut into its parts: what comes before the
// mark, the mark, the space before its words, and its words.
type line = {head: string, mark: string, space: string, words: string}

let cut = (pattern, text, ~marks) =>
  switch RegExp.exec(pattern, text) {
  | Some(m) =>
    let part = i => Scan.capture(m, i)
    let head = Array.fromInitializer(~length=marks, i => part(i))->Array.join("") ++ "["
    let rest = RegExp.exec(spaced, part(marks + 1))
    let (space, words) = rest->Option.mapOr(("", ""), r => (Scan.capture(r, 0), Scan.capture(r, 1)))
    Some({head, mark: part(marks), space, words})
  | None => None
  }

let paste = ({head, mark, space, words}) =>
  words == "" ? `${head}${mark}]` : `${head}${mark}]${space == "" ? " " : space}${words}`

// A stage's words: its title in its bold, and the message after it.
type words = {bold: option<string>, title: string, gap: string, message: string}

let words = text =>
  switch RegExp.exec(boldWords, text) {
  | Some(m) =>
    let part = i => Scan.capture(m, i)
    {bold: Some(part(0)), title: part(1), gap: part(2), message: part(3)}
  | None => {bold: None, title: text, gap: "", message: ""}
  }

let unwords = ({bold, title, gap, message}) => {
  let named = switch bold {
  | Some(b) => `${b}${title}${b}`
  | None => title
  }
  message == "" ? named : `${named}${gap == "" ? " " : gap}${message}`
}

let indent = text => {
  let trimmed = text->String.trimStart
  String.length(text) - String.length(trimmed)
}

let blank = text => String.trim(text) == ""

// The lines an item spans, from 0: its own, and those indented under it.
let span = (lines: array<string>, at) => {
  let own = lines->Array.getUnsafe(at)->indent
  let rec go = (index, last) =>
    switch lines->Array.get(index) {
    | Some(line) if blank(line) => go(index + 1, last)
    | Some(line) if indent(line) > own => go(index + 1, index)
    | _ => last
    }
  (at, go(at + 1, at))
}

type place =
  | Title
  | StageMark(int)
  | StageTitle(int)
  | StageMessage(int)
  | Stage(int)
  | TodoMark(option<int>, int)
  | Todo(option<int>, int)

let keyed = RegExp.fromString("^(?:stage (\\d+))? ?(?:todo (\\d+))? ?(mark|title|message)?$")

let place = key => {
  let number = text => text->Int.fromString->Option.getOr(0) - 1
  switch RegExp.exec(keyed, key) {
  | Some(m) =>
    let part = i => Scan.capture(m, i)
    switch (part(0), part(1), part(2)) {
    | ("", "", "title") => Some(Title)
    | (stage, "", "mark") if stage != "" => Some(StageMark(number(stage)))
    | (stage, "", "title") if stage != "" => Some(StageTitle(number(stage)))
    | (stage, "", "message") if stage != "" => Some(StageMessage(number(stage)))
    | (stage, "", "") if stage != "" => Some(Stage(number(stage)))
    | (stage, todo, "mark") if todo != "" =>
      Some(TodoMark(stage == "" ? None : Some(number(stage)), number(todo)))
    | (stage, todo, "") if todo != "" => Some(Todo(stage == "" ? None : Some(number(stage)), number(todo)))
    | _ => None
    }
  | None => None
  }
}

let todoKey = (stage, todo) =>
  switch stage {
  | Some(s) => `stage ${Int.toString(s + 1)} todo ${Int.toString(todo + 1)}`
  | None => `todo ${Int.toString(todo + 1)}`
  }

/** Apply an act to the plan read from `source`: its `stages`, its `todos`, and the line it opens on. */
let edit = (source, ~stages, ~todos, ~line, act: Draw.act) => {
  let lines = source->String.split("\n")
  let fail = reason => Html.fail(`plan: ${reason}`)
  let unknown = key => fail(`no field "${key}" in this plan`)
  let where = key => place(key)->Option.getOrThrow(~message=`plan: no field "${key}" in this plan`)
  let stage = index => stages->Array.get(index)->Option.getOrThrow(~message="plan: no such stage")
  let todosIn = stage' =>
    switch stage' {
    | Some(index) => stage(index).todos
    | None => todos
    }
  let todo = (stage', index) =>
    todosIn(stage')->Array.get(index)->Option.getOrThrow(~message="plan: no such todo")
  // Lines from 1, as nodes keep them; the array from 0.
  let get = at => lines->Array.getUnsafe(at - 1)
  let set = (at, text) => lines->Array.setUnsafe(at - 1, text)
  let stageParts = at => cut(stageLine, get(at), ~marks=4)->Option.getOrThrow(~message="plan: not a stage")
  let todoParts = at => cut(todoLine, get(at), ~marks=3)->Option.getOrThrow(~message="plan: not a todo")
  let markStage = (at, mark) => set(at, paste({...stageParts(at), mark}))
  // A done stage that takes an open todo moves back in progress, so the
  // plan still reads.
  let opens = stage' =>
    switch stage' {
    | Some(s) if stage(s).state == Done => markStage(stage(s).line, "/")
    | _ => ()
    }
  let markTodo = (at, mark) => set(at, paste({...todoParts(at), mark}))
  let writeStage = (at, change) => {
    let parts = stageParts(at)
    set(at, paste({...parts, words: unwords(change(words(parts.words)))}))
  }
  let caret = switch act {
  | Write({key, text}) =>
    switch where(key) {
    | Title =>
      switch RegExp.exec(openingLine, get(line)) {
      | Some(m) =>
        let part = i => Scan.capture(m, i)
        set(line, text == "" ? part(0) : `${part(0)}${part(1) == "" ? " " : part(1)}${text}`)
      | None => fail("no opening line")
      }
    | StageTitle(index) =>
      writeStage(stage(index).line, w =>
        switch w.bold {
        | None if w.title == "" && text != "" => {...w, bold: Some("**"), title: text}
        | _ => {...w, title: text}
        }
      )
    | StageMessage(index) =>
      writeStage(stage(index).line, w =>
        switch w.bold {
        | None if text != "" => {...w, bold: Some("**"), message: text}
        | _ => {...w, message: text}
        }
      )
    | Todo(stage', index) =>
      let at = todo(stage', index).line
      set(at, paste({...todoParts(at), words: text}))
    | StageMark(_) | TodoMark(_) | Stage(_) => fail(`"${key}" is not a text`)
    }
    Some(key)
  | Tick(key) =>
    switch where(key) {
    | Todo(stage', index) | TodoMark(stage', index) =>
      let one = todo(stage', index)
      markTodo(one.line, one.done ? " " : "x")
      switch stage' {
      | Some(s) if one.done && stage(s).state == Done => markStage(stage(s).line, "/")
      | _ => ()
      }
    | _ => unknown(key)
    }
    None
  | MoveAlong(key) =>
    switch where(key) {
    | Stage(index) | StageMark(index) =>
      let one = stage(index)
      switch one.state {
      | NotStarted => markStage(one.line, "/")
      | Doing =>
        markStage(one.line, "x")
        one.todos->Array.forEach(t => t.done ? () : markTodo(t.line, "x"))
      | Done => markStage(one.line, " ")
      }
    | _ => unknown(key)
    }
    None
  | AddTodoAfter(key) =>
    switch where(key) {
    | Todo(stage', index) =>
      let one = todo(stage', index)
      let parts = todoParts(one.line)
      let (_, last) = span(lines, one.line - 1)
      opens(stage')
      lines->Array.splice(~start=last + 1, ~remove=0, ~insert=[paste({...parts, mark: " ", words: ""})])
      Some(todoKey(stage', index + 1))
    | _ => unknown(key)
    }
  | SplitTodo({key, before, after}) =>
    switch where(key) {
    | Todo(stage', index) =>
      let one = todo(stage', index)
      let parts = todoParts(one.line)
      let (_, last) = span(lines, one.line - 1)
      // Both halves of a ticked todo stay ticked; a new empty todo is open.
      let mark = after == "" ? " " : parts.mark
      if mark == " " {
        opens(stage')
      }
      lines->Array.splice(~start=last + 1, ~remove=0, ~insert=[paste({...parts, mark, words: after})])
      if after != "" {
        set(one.line, paste({...parts, words: before}))
      }
      Some(todoKey(stage', index + 1))
    | _ => unknown(key)
    }
  | AddTodoIn(key) =>
    switch where(key) {
    | Stage(index) =>
      let one = stage(index)
      let new = switch one.todos->Array.get(0) {
      | Some(first) =>
        let at = first.line - 1
        (at, paste({...todoParts(first.line), mark: " ", words: ""}))
      | None =>
        let parts = stageParts(one.line)
        let (_, last) = span(lines, one.line - 1)
        // Indented to the stage's text, past its number and the space after it.
        let pad = " "->String.repeat(String.length(parts.head) - 1)
        (last + 1, `${pad}- [ ]`)
      }
      let (at, text) = new
      opens(Some(index))
      lines->Array.splice(~start=at, ~remove=0, ~insert=[text])
      Some(todoKey(Some(index), 0))
    | _ => unknown(key)
    }
  | AddStage =>
    switch stages->Array.at(-1) {
    | Some(last) =>
      let parts = stageParts(last.line)
      let number = switch RegExp.exec(stageLine, get(last.line)) {
      | Some(m) => Scan.capture(m, 1)->Int.fromString->Option.getOr(Array.length(stages)) + 1
      | None => Array.length(stages) + 1
      }
      let head = switch RegExp.exec(stageLine, get(last.line)) {
      | Some(m) =>
        let part = i => Scan.capture(m, i)
        `${part(0)}${Int.toString(number)}${part(2)}${part(3)}[`
      | None => parts.head
      }
      let (_, end) = span(lines, last.line - 1)
      lines->Array.splice(~start=end + 1, ~remove=0, ~insert=[paste({head, mark: " ", space: "", words: ""})])
      Some(`stage ${Int.toString(Array.length(stages) + 1)} title`)
    | None => fail("a plan of todos has no stages")
    }
  | Remove(key) =>
    switch where(key) {
    | Todo(stage', index) =>
      if stage' == None && Array.length(todos) == 1 {
        fail("a plan keeps one todo at least")
      }
      let (first, last) = span(lines, todo(stage', index).line - 1)
      lines->Array.splice(~start=first, ~remove=last - first + 1, ~insert=[])
      switch (index, stage') {
      | (0, Some(s)) => Some(`stage ${Int.toString(s + 1)} title`)
      | (0, None) => Some(todoKey(None, 0))
      | _ => Some(todoKey(stage', index - 1))
      }
    | Stage(index) =>
      if Array.length(stages) == 1 {
        fail("a plan keeps one stage at least")
      }
      // The stages after it take the number before theirs.
      stages
      ->Array.slice(~start=index + 1)
      ->Array.forEach(s =>
        switch RegExp.exec(stageLine, get(s.line)) {
        | Some(m) =>
          let part = i => Scan.capture(m, i)
          let number = part(1)->Int.fromString->Option.getOr(1) - 1
          set(
            s.line,
            `${part(0)}${Int.toString(number)}${part(2)}${part(3)}[${part(4)}]${part(5)}`,
          )
        | None => ()
        }
      )
      let (first, last) = span(lines, stage(index).line - 1)
      lines->Array.splice(~start=first, ~remove=last - first + 1, ~insert=[])
      index == 0 ? None : Some(`stage ${Int.toString(index)} title`)
    | _ => unknown(key)
    }
  }
  {source: lines->Array.join("\n"), caret}
}
