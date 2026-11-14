// A page of a minidoc site as its editor, in `dev`. Each file a page is
// made of is one section, edited by one editor, in the page where its body
// was. Prose is edited where it stands, and a callout of the site's kinds
// too: `::: ` and a kind makes one. A block minidoc draws opens its
// source in the panel on a click, and the drawing follows each key.
// `::: states` and a space makes a drawing and opens its source. A plan
// is edited where it stands. Each change is written to the file through the
// dev server, 300 ms after the last key. A write that fails never drops the
// edits: a banner stays until a write succeeds, the edits wait in the
// browser, and leaving the page asks first.

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
      <button type_="button" className="edit-pane__close" ariaLabel="Close" title="Close" onClick={_ => onLeave()}>
        {text("×")}
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

// A press anywhere on the page, before the browser moves the focus.
@send external listensPress: (Dom.element, @as("pointerdown") _, Dom.event => unit, @as(json`true`) _) => unit = "addEventListener"
@send external forgetsPress: (Dom.element, @as("pointerdown") _, Dom.event => unit, @as(json`true`) _) => unit = "removeEventListener"
@val external document: Dom.element = "document"
@get external targetOf: Dom.event => Nullable.t<Dom.element> = "target"
@send external closest: (Dom.element, string) => Nullable.t<Dom.element> = "closest"
@send external contains: (Dom.element, Dom.element) => bool = "contains"

/**
 Whether a press leaves the panel: it is outside the card and outside the
 section. In the section, the editor decides: a press in its text closes the
 panel, and a press on a block opens that block's source.
*/
let outside = (target: Dom.element, ~section: option<Dom.element>) =>
  target->closest(".edit-pane")->Nullable.isNullable &&
    !(section->Option.mapOr(false, section => section->contains(target)))

/** A block's source in the panel: each key changes the block in the page. A press outside closes it. */
module Paned = {
  @react.component
  let make = (~value: Live.value, ~options, ~onChange: option<Live.value => unit>, ~onLeave, ~section: unit => option<Dom.element>) => {
    let leave = React.useRef(onLeave)
    leave.current = onLeave
    React.useEffect0(() => {
      let press = event =>
        switch targetOf(event)->Nullable.toOption {
        | Some(target) if outside(target, ~section=section()) => leave.current()
        | _ => ()
        }
      document->listensPress(press)
      Some(() => document->forgetsPress(press))
    })
    <div className="edit-pane__block" onKeyDown={leaves(onLeave, _)}>
      <Bar source=value.source onLeave />
      {switch onChange {
      | Some(onChange) =>
        <Live.Pane value options autoFocus=true onChange={source => onChange(Live.read(source, options))} />
      | None => <pre className="pane__source"> {text(value.source)} </pre>
      }}
    </div>
  }
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

/** An image on a line of its own, as its markdown line: drawn, and not edited here. */
let image = Rule.make({
  data: {
    parse: value =>
      switch value {
      | String(line) => Ok(line)
      | _ => Error("An image is its markdown line")
      },
    encode: line => JSON.String(line),
  },
  view: {
    render: ({value}: Rule.shown<string>) =>
      switch RegExp.exec(/^!\[([^\]\n]*)\]\(([^\s()]*)(?:\s+"([^"\n]*)")?\)\s*$/, value) {
      | Some(found) =>
        let part = index => found->RegExp.Result.matches->Array.get(index)->Option.flatMap(x => x)
        <span className="edit-image">
          <img src={part(1)->Option.getOr("")} alt={part(0)->Option.getOr("")} title=?{part(2)} />
        </span>
      | None => <span> {text(value)} </span>
      },
  },
})

/** The rules of a page: minidoc's blocks through the panel, the plan in place, and images drawn. */
let rules = (options: options, ~section: unit => option<Dom.element>) =>
  Dict.fromArray([
    (Editor.Page.imageFormat, image),
    (
      Page.blockFormat,
      Rule.make({
        data: data(options),
        view: {
          render: shown => drawn(options, shown),
          pane: ({value, onChange, onLeave}: Rule.paned<Live.value>) =>
            <Paned
              value options section onChange={onChange->Option.map(onChange => value => onChange({value: value}))} onLeave
            />,
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

/** What the page says to the person, at the bottom-left of the page. */
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

// ── A failed save ──────────────────────────────────────────────────────

/**
 A banner at the top of the page that stays until `clearAlert` removes it:
 a failed save of the file at `path`, and what the person can do. Each file
 has one banner; a new one takes its place. A button's act returns a text
 to show on it after the click, or nothing.
*/
let alert: (string, string, array<(string, unit => option<string>)>) => unit = %raw(`(path, message, acts) => {
  let box = document.querySelector(".edit-alerts")
  if (!box) {
    box = document.createElement("div")
    box.className = "edit-alerts"
    document.body.prepend(box)
  }
  let banner = [...box.children].find((b) => b.dataset.path === path)
  if (!banner) {
    banner = document.createElement("div")
    banner.className = "edit-alert"
    banner.dataset.path = path
    banner.setAttribute("role", "alert")
    box.append(banner)
  }
  const text = document.createElement("p")
  text.className = "edit-alert__text"
  text.textContent = message
  const buttons = document.createElement("div")
  buttons.className = "edit-alert__acts"
  for (const [label, act] of acts) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "edit-alert__act"
    button.textContent = label
    button.onclick = () => { const said = act(); if (said) button.textContent = said }
    buttons.append(button)
  }
  banner.replaceChildren(text, buttons)
}`)

let clearAlert: string => unit = %raw(`(path) => {
  const box = document.querySelector(".edit-alerts")
  for (const b of box ? [...box.children] : []) if (b.dataset.path === path) b.remove()
  if (box && !box.children.length) box.remove()
}`)

/** Put `text` on the clipboard, in a page served over http too. */
let copy: string => unit = %raw(`(text) => {
  const by = () => {
    const area = document.createElement("textarea")
    area.value = text
    area.style.cssText = "position:fixed;top:0;left:0;opacity:0"
    document.body.append(area)
    area.select()
    try { document.execCommand("copy") } finally { area.remove() }
  }
  if (navigator.clipboard?.writeText) navigator.clipboard.writeText(text).catch(by)
  else by()
}`)

/** The edits of a file that are not on disk, kept in the browser until a save of them succeeds. */
type draft = {text: string, base: string}

let draftKey = path => "minidoc-draft:" ++ path
let keepDraft: (string, draft) => unit = %raw(`(key, draft) => { try { localStorage.setItem(key, JSON.stringify(draft)) } catch {} }`)
let dropDraft: string => unit = %raw(`(key) => { try { localStorage.removeItem(key) } catch {} }`)
let draftOf: string => option<draft> = %raw(`(key) => {
  try {
    const draft = JSON.parse(localStorage.getItem(key) || "null")
    return draft && typeof draft.text === "string" && typeof draft.base === "string" ? draft : undefined
  } catch { return undefined }
}`)

// The files whose edits are not on disk yet. Leaving the page, or
// reloading it, asks first while one is left.
let unsaved: Set.t<string> = Set.make()
let guard: Set.t<string> => unit = %raw(`(unsaved) => addEventListener("beforeunload", (event) => {
  if (unsaved.size) { event.preventDefault(); event.returnValue = "" }
})`)

/**
 The panel's card: the person moves it by its bar and makes it bigger by
 the grip at its top-left corner. Its place is its distance from the
 bottom-right corner of the window, kept with its size in localStorage, and
 it stays inside the window. A press on the bar or the grip keeps the focus
 where it is, so the caret stays in the source.
*/
let card: Dom.element => unit = %raw(`(aside) => {
  const key = "minidoc-pane"
  const least = { width: 288, height: 160 }
  // The window without its scrollbars, which a fixed card is placed in.
  const wide = () => document.documentElement.clientWidth
  const high = () => document.documentElement.clientHeight
  let at = {}
  try { at = JSON.parse(localStorage.getItem(key) || "{}") || {} } catch {}
  const fit = () => {
    const width = at.width ?? least.width, height = at.height ?? least.height
    if (at.width !== undefined) at.width = Math.max(least.width, Math.min(at.width, wide()))
    if (at.height !== undefined) at.height = Math.max(least.height, Math.min(at.height, high()))
    if (at.right !== undefined) at.right = Math.max(0, Math.min(at.right, wide() - Math.min(width, wide())))
    if (at.bottom !== undefined) at.bottom = Math.max(0, Math.min(at.bottom, high() - Math.min(height, high())))
  }
  const show = () => {
    fit()
    const px = (n) => n === undefined ? "" : n + "px"
    aside.style.right = px(at.right)
    aside.style.bottom = px(at.bottom)
    aside.style.width = px(at.width)
    aside.style.height = px(at.height)
    aside.style.maxHeight = at.height === undefined ? "" : "none"
  }
  const keep = () => { try { localStorage.setItem(key, JSON.stringify(at)) } catch {} }
  const grip = document.createElement("div")
  grip.className = "edit-pane__grip"
  grip.setAttribute("aria-hidden", "true")
  aside.prepend(grip)
  const held = (event) => {
    const byGrip = event.target.closest(".edit-pane__grip")
    const byBar = !byGrip && event.target.closest(".edit-pane__bar") && !event.target.closest("button")
    return byGrip ? "grip" : byBar ? "bar" : null
  }
  // A press on the bar or the grip does not move the focus.
  aside.addEventListener("mousedown", (event) => { if (held(event)) event.preventDefault() })
  aside.addEventListener("pointerdown", (event) => {
    const part = held(event)
    if (!part || event.button !== 0) return
    event.preventDefault()
    const box = aside.getBoundingClientRect()
    const from = { x: event.clientX, y: event.clientY, right: wide() - box.right, bottom: high() - box.bottom, width: box.width, height: box.height }
    const move = (next) => {
      const dx = next.clientX - from.x, dy = next.clientY - from.y
      if (part === "bar") {
        at = { ...at, right: from.right - dx, bottom: from.bottom - dy, width: at.width ?? from.width, height: at.height ?? from.height }
      } else {
        at = { ...at, right: from.right, bottom: from.bottom, width: Math.min(from.width - dx, wide() - from.right), height: Math.min(from.height - dy, high() - from.bottom) }
      }
      show()
    }
    const stop = () => {
      removeEventListener("pointermove", move)
      removeEventListener("pointerup", stop)
      removeEventListener("pointercancel", stop)
      keep()
    }
    addEventListener("pointermove", move)
    addEventListener("pointerup", stop)
    addEventListener("pointercancel", stop)
  })
  addEventListener("resize", show)
  show()
}`)

/** The one panel of the page, a card over its bottom-right corner, where a block's source opens. */
let panel: unit => Dom.element = %raw(`() => {
  let aside = document.querySelector(".edit-pane")
  if (!aside) {
    aside = document.createElement("aside")
    aside.className = "edit-pane"
    aside.setAttribute("aria-label", "Source")
    document.body.append(aside)
    card(aside)
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
  let make = (~page: Page.t, ~path: string, ~base: string, ~options: options, ~restored=false) => {
    let kinds = React.useMemo0(() => Live.Blocks.callouts(options))
    let host = React.useRef(Nullable.null)
    let state = React.useMemo0(() =>
      View.prepare(
        page.section,
        ~rules=rules(options, ~section=() => host.current->Nullable.toOption),
        // `::: states` and a space, or Enter, makes the drawing, and its
        // source opens in the panel.
        ~shortcuts=[Editor.Shortcut.colon(~blocks=Page.blocks(options))]
        ->Array.concat(Editor.Shortcut.markdown)
        ->Array.concat([Editor.Shortcut.callout(~kinds=kinds->Array.map(Pair.first))]),
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
    React.useEffect0(() => {
      let written = ref(base)
      let waiting = ref(None)
      let reads = source => (Live.read(source, options).read)->Result.isOk
      let current = () => Page.write(page, Storage.write(View.doc(state), ~id="page"), ~reads)
      let saved = () => {
        dropDraft(draftKey(path))
        unsaved->Set.delete(path)->ignore
        clearAlert(path)
      }
      let copies = (label, text) => (label, () => {
        copy(text())
        Some("Copied")
      })
      let rec save = async () => {
        let text = current()
        if text == written.contents {
          saved()
        } else {
          unsaved->Set.add(path)
          keepDraft(draftKey(path), {text, base: written.contents})
          switch await putFile(path, text, written.contents) {
          | {status: 200} =>
            written := text
            if current() == text {
              saved()
            }
          // The file changed on disk since the page read it: the person
          // chooses which text stays.
          | {status: 409, body} =>
            alert(
              path,
              `${path} changed on disk while you edited it. Your edits are not saved.`,
              [
                copies("Copy my text", current),
                ("Keep my text", () => {
                  written := body
                  run()
                  None
                }),
                ("Load the file", () => {
                  dropDraft(draftKey(path))
                  unsaved->Set.delete(path)->ignore
                  reload()
                  None
                }),
              ],
            )
          | {status, body} => failed(`${path} is not saved (${Int.toString(status)}): ${body}`)
          }
        }
      }
      and failed = message =>
        alert(
          path,
          `${message}. Your edits are kept in this browser.`,
          [copies("Copy my text", current), ("Retry", () => {
            run()
            Some("Retrying…")
          })],
        )
      and run = () =>
        save()
        ->Promise.catch(error => {
          failed(`${path} is not saved: ${error->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("an error")}`)
          Promise.resolve()
        })
        ->ignore
      let stops = Tilia.watch(() => View.doc(state), _ => {
        unsaved->Set.add(path)
        waiting.contents->Option.forEach(cancel)
        waiting := Some(later(run, 300))
      })
      // Edits restored from a draft are written at once.
      if restored {
        run()
      }
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
      <View state storage paneAt=slot prefix kinds removable=Live.Blocks.removable />
    </div>
  }
}

@module("react-dom/client") external createRoot: Dom.element => ReactDOM.Client.Root.t = "createRoot"

let noticed = ref(false)

@get @scope("dataset") external langOf: Dom.element => Nullable.t<string> = "minidocLang"

/** Draw the file at `path` as its editor, in place of `element`'s content. The element's `data-minidoc-lang` is the page's lang, as the build gave it to the blocks. */
let mount = async (element: Dom.element, ~path: string, ~options: options) => {
  let options = switch langOf(element)->Nullable.toOption {
  | Some(lang) => {...options, lang}
  | None => options
  }
  if !noticed.contents {
    noticed := true
    guard(unsaved)
    if takeMark() {
      say("The page reloaded: a file changed outside it.")
    }
  }
  switch await fetchFile(path) {
  | {status: 200, body} =>
    let root = createRoot(element)
    let draw = (text, ~restored) =>
      root->ReactDOM.Client.Root.render(
        <Section key={restored ? "restored" : "file"} page={Page.read(text, ~options)} path base=body options restored />,
      )
    draw(body, ~restored=false)
    // Edits that a reload or a closed page left in the browser, not on disk.
    let key = draftKey(path)
    switch draftOf(key) {
    | Some(draft) if draft.text != body =>
      let changed = draft.base != body ? " The file changed since: restoring them replaces it." : ""
      alert(
        path,
        `${path} has edits from before the page reloaded that are not on disk.${changed}`,
        [
          ("Restore my edits", () => {
            clearAlert(path)
            draw(draft.text, ~restored=true)
            None
          }),
          ("Copy my text", () => {
            copy(draft.text)
            Some("Copied")
          }),
          ("Discard them", () => {
            dropDraft(key)
            clearAlert(path)
            None
          }),
        ],
      )
    | Some(_) => dropDraft(key)
    | None => ()
    }
  | {status, body} => say(`${path} cannot be edited (${Int.toString(status)}): ${body}`)
  }
}
