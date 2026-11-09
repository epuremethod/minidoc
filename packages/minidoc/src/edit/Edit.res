// A page of a minidoc site as its editor, in `dev`. Each file a page is
// made of is one section, edited by one editor, in the page where its body
// was. Prose is edited where it stands, and a callout of the site's kinds
// too: `::: ` and a kind makes one. A block minidoc draws opens its
// source in the panel on a click, and the drawing follows each key. A plan
// is edited where it stands. Each change is written to the file through the
// dev server, 300 ms after the last key.

module Live = EpureBlocks.Live
module View = TiliaEditor.View
module Rule = TiliaEditor.Rule
module Storage = Editor.Storage

type options = Live.Blocks.options

let text = React.string

// ── The rules ───────────────────────────────────────────────────────────

/** What a block of the panel is called, from its first line. */
let named = (source: string) => {
  let first = source->String.split("\n")->Array.get(0)->Option.getOr("")->String.trim
  switch RegExp.exec(/^(?::{3,}|`{3,}|~{3,})\s*([A-Za-z0-9_-]+)/, first) {
  | Some(m) => m->RegExp.Result.matches->Array.get(0)->Option.flatMap(x => x)->Option.getOr("code")
  | None =>
    if first->String.startsWith("|") {
      "table"
    } else if first->String.startsWith(">") {
      "quote"
    } else if first->String.startsWith("#") {
      "title"
    } else if RegExp.test(/^\d+[.)]/, first) {
      "numbered list"
    } else if RegExp.test(/^(`{3,}|~{3,})/, first) {
      "code"
    } else {
      "block"
    }
  }
}

let data = (options): Rule.data<Live.value> => {
  parse: value =>
    switch value {
    | String(markdown) => Ok(Live.read(markdown, options))
    | _ => Error("A block is its markdown")
    },
  encode: value => JSON.String(value.source),
}

/** A block as minidoc draws it. It stays the same element while its source changes, and keeps its last good form. */
let drawn = (options, {value}: Rule.shown<Live.value>) =>
  <div className="edit-block">
    <Live.Drawing value options />
  </div>

/** The bar above a source in the panel: what it is, and how to leave. */
module Bar = {
  @react.component
  let make = (~source: string, ~onLeave: unit => unit) =>
    <div className="edit-pane__bar">
      <span className="edit-pane__name"> {text(named(source))} </span>
      <span className="edit-pane__hint"> {text("esc or ⌘↵ closes")} </span>
      <button type_="button" className="edit-pane__done" onClick={_ => onLeave()}>
        {text("done")}
      </button>
    </div>
}

let leaves = (onLeave, event) =>
  switch (ReactEvent.Keyboard.key(event), ReactEvent.Keyboard.metaKey(event)) {
  | ("Escape", _) | ("Enter", true) =>
    ReactEvent.Keyboard.preventDefault(event)
    onLeave()
  | _ => ()
  }

/** A block's source in the panel: each key changes the block in the page. */
module Paned = {
  @react.component
  let make = (~value: Live.value, ~options, ~onChange: option<Live.value => unit>, ~onLeave) =>
    <div className="edit-pane__block" onKeyDown={leaves(onLeave, _)}>
      <Bar source=value.source onLeave />
      {switch onChange {
      | Some(onChange) =>
        <Live.Pane value options autoFocus=true onChange={source => onChange(Live.read(source, options))} />
      | None => <pre className="pane__source"> {text(value.source)} </pre>
      }}
    </div>
}

// React takes a callback where it takes a ref object, and the editor's
// block takes the place live gives: "start", "end" or an offset.
external blockRef: (Nullable.t<Live.handle> => unit) => React.ref<Nullable.t<TiliaEditor.Block.handle>> =
  "%identity"

/** A text of a plan, written in the editor's own block, as the page's prose is. */
let field = (props: Live.textField) =>
  <TiliaEditor.Block
    markdown=props.markdown
    onChange=props.onChange
    onEnter={({before, after}) => props.onEnter(Some(({before, after}: Live.cut)))}
    onBackspaceAtStart=props.onBackspaceAtStart
    onLeave=props.onLeave
    ref={Some(blockRef(props.ref))}
  />

let editable = (value: Live.value) =>
  switch value.read {
  | Ok(nodes) => Live.Blocks.editable(nodes)
  | Error(_) => false
  }

/** A plan, edited where it stands. Its source is behind a switch. */
module Plan = {
  @react.component
  let make = (~value: Live.value, ~options, ~onChange: Live.value => unit, ~onLeave) => {
    let (source, sources) = React.useState(() => !editable(value))
    <div className="edit-plan" onKeyDown={event => if ReactEvent.Keyboard.key(event) == "Escape" { onLeave() }}>
      <button type_="button" className="edit-plan__switch" onClick={_ => sources(was => !was)}>
        {text(source ? "plan" : "source")}
      </button>
      {source
        ? <>
            <Live.Pane value options autoFocus=true onChange={source => onChange(Live.read(source, options))} />
            <Live.Drawing value options />
          </>
        : <Live.Editor
            value options field onChange={source => onChange(Live.read(source, options))}
          />}
    </div>
  }
}

/** The rules of a page: minidoc's blocks through the panel, and the plan in place. */
let rules = (options: options) =>
  Dict.fromArray([
    (
      Page.blockFormat,
      Rule.make({
        data: data(options),
        view: {
          render: shown => drawn(options, shown),
          pane: ({value, onChange, onLeave}: Rule.paned<Live.value>) =>
            <Paned value options onChange={onChange->Option.map(onChange => value => onChange({value: value}))} onLeave />,
        },
      }),
    ),
    (
      Page.planFormat,
      Rule.make({
        data: data(options),
        view: {
          render: shown => drawn(options, shown),
          editor: ({value, onChange, onLeave}: Rule.edited<Live.value>) =>
            <Plan value options onChange={value => onChange({value: value})} onLeave />,
        },
      }),
    ),
  ])

// ── Reading and writing the file ───────────────────────────────────────

type answer = {status: int, body: string}

let fetchFile: string => promise<answer> = %raw(`async (path) => {
  const res = await fetch((window.__minidocBase || "") + "/__minidoc/file?path=" + encodeURIComponent(path), {headers: {"x-minidoc-edit": "1"}})
  return {status: res.status, body: await res.text()}
}`)

let putFile: (string, string, string) => promise<answer> = %raw(`async (path, text, base) => {
  const res = await fetch((window.__minidocBase || "") + "/__minidoc/file?path=" + encodeURIComponent(path), {
    method: "PUT",
    headers: {"x-minidoc-edit": "1", "content-type": "application/json"},
    body: JSON.stringify({text, base, page: window.__minidocPage || ""}),
  })
  return {status: res.status, body: await res.text()}
}`)

// The injected reload script marks the page before it reloads it.
let reloaded = "minidoc-reloaded"
let takeMark: unit => bool = %raw(`() => {
  try { const was = sessionStorage.getItem("minidoc-reloaded"); sessionStorage.removeItem("minidoc-reloaded"); return was === "1" } catch { return false }
}`)
let reload: unit => unit = %raw(`() => { try { sessionStorage.setItem("minidoc-reloaded", "1") } catch {} location.reload() }`)

/** What the page says to the person, at the foot of the panel. */
let say: string => unit = %raw(`(message) => {
  let note = document.querySelector(".edit-note")
  if (!note) {
    note = document.createElement("p")
    note.className = "edit-note"
    note.setAttribute("role", "status")
    document.body.append(note)
  }
  note.textContent = message
  clearTimeout(note.timer)
  note.timer = setTimeout(() => note.remove(), 6000)
}`)

/** The one panel of the page, beside the text, where a block's source opens. */
let panel: unit => Dom.element = %raw(`() => {
  let aside = document.querySelector(".edit-pane")
  if (!aside) {
    aside = document.createElement("aside")
    aside.className = "edit-pane"
    aside.setAttribute("aria-label", "Source")
    document.body.append(aside)
  }
  const slot = document.createElement("div")
  aside.append(slot)
  return slot
}`)

type timer
@val external later: (unit => unit, int) => timer = "setTimeout"
@val external cancel: timer => unit = "clearTimeout"

type key = {key: string, metaKey: bool, ctrlKey: bool}
@send external listens: (Dom.element, @as("keydown") _, key => unit, @as(json`true`) _) => unit = "addEventListener"
@send external stopPropagation: key => unit = "stopPropagation"

/** A section of the page, edited, and written to its file. */
module Section = {
  @react.component
  let make = (~page: Page.t, ~path: string, ~base: string, ~options: options) => {
    let kinds = React.useMemo0(() => Live.Blocks.callouts(options))
    let state = React.useMemo0(() =>
      View.prepare(
        page.section,
        ~rules=rules(options),
        ~shortcuts=Editor.Shortcut.markdown->Array.concat([
          Editor.Shortcut.callout(~kinds=kinds->Array.map(Pair.first)),
        ]),
      )
    )
    // Each section keys its blocks' DOM ids with a prefix of its own, so the
    // sections of one page never share an id.
    let prefix = TiliaEditor.Block.prefixOf(React.useId())
    // The page saves on its own: the editor's port is never asked to save.
    let storage: Editor.Section.storage = {
      sections: [],
      update: _ => (),
      merge: (~base as _, ~local, ~remote as _) => local,
    }
    let slot = React.useMemo0(() => panel())
    let host = React.useRef(Nullable.null)
    React.useEffect0(() => {
      let written = ref(base)
      let waiting = ref(None)
      let reads = source => (Live.read(source, options).read)->Result.isOk
      let save = async () => {
        let text = Page.write(page, Storage.write(View.doc(state), ~id="page"), ~reads)
        if text != written.contents {
          switch await putFile(path, text, written.contents) {
          | {status: 200} => written := text
          | {status: 409} => reload()
          | {status, body} => say(`${path} was not written (${Int.toString(status)}): ${body}`)
          }
        }
      }
      let stops = Tilia.watch(() => View.doc(state), _ => {
        waiting.contents->Option.forEach(cancel)
        waiting := Some(
          later(() =>
            save()
            ->Promise.catch(error => {
              say(`${path} was not written: ${error->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("an error")}`)
              Promise.resolve()
            })
            ->ignore
          , 300),
        )
      })
      Some(stops)
    })
    // The key that inserts an atom of the editor's own: a page has none.
    React.useEffect0(() => {
      host.current
      ->Nullable.toOption
      ->Option.forEach(element =>
        element->listens(event =>
          if (event.metaKey || event.ctrlKey) && event.key->String.toLowerCase == "m" {
            event->stopPropagation
          }
        )
      )
      None
    })
    <div className="edit-section" ref={ReactDOM.Ref.domRef(host)}>
      <View state storage paneAt=slot prefix kinds />
    </div>
  }
}

@module("react-dom/client") external createRoot: Dom.element => ReactDOM.Client.Root.t = "createRoot"

let noticed = ref(false)

/** Draw the file at `path` as its editor, in place of `element`'s content. */
let mount = async (element: Dom.element, ~path: string, ~options: options) => {
  if !noticed.contents {
    noticed := true
    if takeMark() {
      say("The page reloaded: a file changed outside it.")
    }
  }
  switch await fetchFile(path) {
  | {status: 200, body} =>
    let page = Page.read(body, ~options)
    createRoot(element)->ReactDOM.Client.Root.render(<Section page path base=body options />)
  | {status, body} => say(`${path} cannot be edited (${Int.toString(status)}): ${body}`)
  }
}
