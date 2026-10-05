// The `flow` block, in ADJ's form: a numbered list whose top items are
// columns, each with a bold title and a numbered list of steps. A bullet
// list under a step holds its details. A flat numbered list is one column
// with no title.

open Node

type rec list = {ordered: bool, items: array<item>}
and item = {mutable text: option<string>, lists: array<list>}

// The lists of `body`, as markdown-it reads them: each item keeps the
// source of its first line and the lists nested in it.
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
      let item = {text: None, lists: []}
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

let render = (md, label, columns) => {
  let inline = text => Markdown.renderInline(md, text, Markdown.env())
  let step = (s: step) => {
    let details =
      s.details == []
        ? ""
        : `\n<ul class="flow__details">\n${s.details
            ->Array.map(d => `<li>${inline(d)}</li>`)
            ->Array.join("\n")}\n</ul>`
    `<li class="flow__step"><p class="flow__text">${inline(s.text)}</p>${details}\n</li>`
  }
  let column = (c: column) =>
    `<li class="flow__column">${c.title->Option.mapOr("", t =>
        `<p class="flow__title">${inline(t)}</p>`
      )}\n<ol class="flow__steps">\n${c.steps->Array.map(step)->Array.join("\n")}\n</ol>\n</li>`
  let label = Html.escape(label)
  `<aside class="callout callout--flow" aria-label="${label}"><p class="callout__label">${label}</p><div class="callout__body">\n<ol class="flow">\n${columns
    ->Array.map(column)
    ->Array.join("\n")}\n</ol>\n</div></aside>\n`
}
