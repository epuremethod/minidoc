// The `flow` block, in ADJ's form: a numbered list whose top items are
// columns, each with a bold title and a numbered list of steps. A bullet
// list under a step holds its details. A flat numbered list is one column
// with no title.

@@jsxConfig({version: 4, module_: "Draw"})

open Node

type rec list = {ordered: bool, items: array<item>}
and item = {mutable text: option<string>, lists: array<list>, line: int}

// The lists of `body`, as markdown-it reads them: each item keeps the
// source of its first line, the lists nested in it, and its line in `body`,
// from 0.
let lists = (md, body) => {
  let top = []
  let openLists: array<list> = []
  let openItems: array<item> = []
  Markdown.parse(md, body, Markdown.env())->Array.forEach(token =>
    switch token.kind {
    | "ordered_list_open" | "bullet_list_open" =>
      let list = {ordered: token.kind == "ordered_list_open", items: []}
      switch openItems->Array.at(-1) {
      | Some(item) => item.lists->Array.push(list)
      | None => top->Array.push(list)
      }
      openLists->Array.push(list)
    | "ordered_list_close" | "bullet_list_close" => openLists->Array.pop->ignore
    | "list_item_open" =>
      let line = token.map->Nullable.toOption->Option.flatMap(m => m->Array.get(0))->Option.getOr(0)
      let item = {text: None, lists: [], line}
      openLists->Array.at(-1)->Option.forEach(list => list.items->Array.push(item))
      openItems->Array.push(item)
    | "list_item_close" => openItems->Array.pop->ignore
    | "inline" =>
      openItems
      ->Array.at(-1)
      ->Option.forEach(item =>
        if item.text->Option.isNone {
          item.text = Some(token.content)
        }
      )
    | _ => ()
    }
  )
  top
}

let bold = RegExp.fromString("^(?:\\*\\*(.+)\\*\\*|__(.+)__)$")

let title = text =>
  switch RegExp.exec(bold, text) {
  | Some(m) => m->RegExp.Result.matches->Array.keepSome->Array.get(0)->Option.getOr(text)
  | None => text
  }

let ordered = (item: item) => item.lists->Array.find(l => l.ordered)

let step = (item: item) => {
  text: item.text->Option.getOr(""),
  details: item.lists
  ->Array.find(l => !l.ordered)
  ->Option.mapOr([], l => l.items->Array.map(i => i.text->Option.getOr(""))),
}

let read = (md, body, label) => {
  let list = switch lists(md, body)->Array.find(l => l.ordered) {
  | Some(list) => list
  | None => Html.fail("flow: a flow is a numbered list")
  }
  let columns = if list.items->Array.some(item => ordered(item)->Option.isSome) {
    list.items->Array.map(item => {
      title: item.text->Option.map(title),
      steps: ordered(item)->Option.mapOr([], l => l.items->Array.map(step)),
    })
  } else {
    [{title: None, steps: list.items->Array.map(step)}]
  }
  Flow({label, columns})
}

let text = Draw.string
let nl = Draw.string("\n")

let draw = (md, label, columns) => {
  let inline = (key, source) =>
    Draw.field(~key, ~value=source, Draw.raw(Markdown.renderInline(md, source, Markdown.env())))
  let step = (s: step, ~at) =>
    <li className="flow__step">
      <p className="flow__text"> {inline(at, s.text)} </p>
      {s.details == []
        ? Draw.null
        : <>
            nl
            <ul className="flow__details">
              nl
              {s.details
              ->Array.mapWithIndex((d, i) =>
                <li> {inline(`${at} detail ${Int.toString(i + 1)}`, d)} </li>
              )
              ->Draw.joined("\n")}
              nl
            </ul>
          </>}
      nl
    </li>
  let column = (c: column, index) => {
    let at = `column ${Int.toString(index + 1)}`
    <li className="flow__column">
      {switch c.title {
      | Some(t) => <p className="flow__title"> {inline(`${at} title`, t)} </p>
      | None => Draw.null
      }}
      nl
      <ol className="flow__steps">
        nl
        {c.steps
        ->Array.mapWithIndex((s, i) => step(s, ~at=`${at} step ${Int.toString(i + 1)}`))
        ->Draw.joined("\n")}
        nl
      </ol>
      nl
    </li>
  }
  <>
    <aside className="callout callout--flow" ariaLabel=label>
      <p className="callout__label"> {text(label)} </p>
      <div className="callout__body">
        nl
        <ol className="flow">
          nl
          {columns->Array.mapWithIndex(column)->Draw.joined("\n")}
          nl
        </ol>
        nl
      </div>
    </aside>
    nl
  </>
}
