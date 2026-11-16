// One file of the page, its head or a section, as the editor's view. It is
// drawn with editing off, on the server and at hydration, so the two give
// the same HTML; editing turns on once the page has hydrated.
//
// Each file is the editor's engine for one markdown text: it keeps the
// bytes of each block nobody edited and of the frontmatter, saves 300 ms
// after the last key, and merges a file that lands with what the person
// typed. minidoc adds the sync: each save names its file and the version
// it starts from, and a file from the server lands in the engine.
//
// A block that the editor does not read itself, such as a quote or a
// `:::` drawing, is an atom of the editor's markdown format, drawn by the
// blocks, as live draws it.

module View = TiliaEditor.View
module Markdown = TiliaEditor.Markdown
module Rule = TiliaEditor.Rule
module Live = MinidocLive.Live

/** What the site knows of its text: the blocks' options with its own callouts, the callouts the editor draws itself, and the blocks. */
type kit = {
  options: MinidocBlocks.Blocks.options,
  kinds: array<(string, string)>,
  kindNames: array<string>,
  blocks: dict<string>,
}

/** The kit of a site whose template names `callouts`, by name with their label. */
let kitOf = (callouts: dict<string>): kit => {
  let options: MinidocBlocks.Blocks.options = {callouts: callouts}
  let kinds = MinidocBlocks.Blocks.callouts(options)
  {
    options,
    kinds,
    kindNames: kinds->Array.map(((kind, _)) => kind),
    blocks: MinidocBlocks.Blocks.keys(options)->Array.map(key => (key, Editor.Page.format))->Dict.fromArray,
  }
}

/** The kit of a folder with no callout of its own. */
let plain = kitOf(Dict.make())

/** A file's markdown, read as the editor reads it. */
let read = (kit: kit, text: string) => Editor.Page.read(text, ~kinds=kit.kindNames, ~blocks=kit.blocks)

/** A block of the editor's markdown format, drawn by the blocks; an image, drawn by minidoc. */
let rules = ({options}: kit, host: Picture.host) => Dict.fromArray([
  (Editor.Page.imageFormat, Picture.rule(host)),
  (
    Editor.Page.format,
    Rule.make({
      data: {
        parse: value =>
          switch value {
          | String(markdown) => Ok(Live.read(markdown, options))
          | _ => Error("A block is its markdown")
          },
        encode: value => JSON.String(value.source),
      },
      view: {
        render: ({value}: Rule.shown<Live.value>) =>
          <div className="edit-block">
            <Live.Drawing value options />
          </div>,
      },
    }),
  ),
])

type timer
@val external later: (unit => unit, int) => timer = "setTimeout"

/** A message of the sync, as the page reads it. */
type heard = {
  saved?: string,
  file?: string,
  stale?: string,
  version?: int,
  text?: string,
  stored?: string,
  @as("as") as_?: string,
  refused?: string,
  reason?: string,
  images?: array<string>,
}

// ── A pasted image ──────────────────────────────────────────────────────

let isImageFile: TiliaEditor.Browser.file => bool = %raw(`(file) => /^image\//.test(file.type || "")`)
let extensionOf: TiliaEditor.Browser.file => string = %raw(`(file) => {
  const type = (file.type || "").replace(/^image\//, "")
  return { jpeg: "jpg", "svg+xml": "svg" }[type] || type || "png"
}`)
let copyOf: TiliaEditor.Browser.file => string = %raw(`(file) => URL.createObjectURL(file)`)
let bytesOf: TiliaEditor.Browser.file => promise<string> = %raw(`(file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result).replace(/^data:[^,]*,/, ""))
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(file)
  })`)

/** The name of the next image pasted into the file `path`: `images/notes-1.png`. */
let nameFor = (host: Picture.host, ~path: string, ~extension: string) => {
  let stem = Site.base(path)
  let rec next = number => {
    let name = `${Site.imagesFolder}${stem}-${Int.toString(number)}.${extension}`
    host.site.images->Array.includes(name) || host.uploads->Dict.has(name) ? next(number + 1) : name
  }
  next(1)
}
external heard: JSON.t => heard = "%identity"

/** The engine's options: the callouts, the blocks, and the rules that draw them. */
let engineOptions = ({kinds, blocks}: kit, drawn): Markdown.options => {kinds, blocks, rules: drawn}

/** What the page holds of the sync. */
type held = {
  mutable version: int,
  /** The text the server holds. */
  mutable written: string,
  /** A save sent and not answered yet: its text. */
  mutable sending: option<string>,
  /** Sends the engine's text, once the channel is open. */
  mutable save: unit => unit,
}

@react.component
let make = (
  ~site: Site.t,
  ~kit: kit,
  // The way from the page to the folder.
  ~root: string="",
  ~path: string,
  // What goes before each block's id: the head has none, a section its own.
  ~prefix: string="",
  ~text: string,
  ~version: int,
  ~channel: option<Channel.t>=?,
  ~outline: option<Outline.t>=?,
) => {
  // The renames asked and not answered yet: their answer, by the new name.
  let renaming: dict<option<string> => unit> = React.useMemo0(() => Dict.make())
  let host: Picture.host = React.useMemo0(() => {
    Picture.site,
    root,
    uploads: Tilia.tilia(Dict.make()),
    rename: (from, to_) =>
      Promise.make((resolve, _) =>
        switch channel {
        | Some(channel) =>
          renaming->Dict.set(to_, resolve)
          channel.send({"renames": from, "as": to_}->Obj.magic)
        | None => resolve(Some("The page is not served by dev: it cannot rename a file."))
        }
      ),
  })
  let held = React.useMemo0(() => {version, written: text, sending: None, save: () => ()})
  let notes = React.useMemo0(() =>
    Markdown.make(~markdown=text, ~onChange=_ => held.save(), ~options=engineOptions(kit, rules(kit, host)))
  )
  let state = notes.state
  let storage = notes.storage
  // A pasted image: named, drawn at once from the browser's own copy, sent
  // to `dev`, and its pane opened on its text.
  let paste: option<View.paste> = channel->Option.map(channel => file =>
    if isImageFile(file) {
      let name = nameFor(host, ~path, ~extension=extensionOf(file))
      let value = `![](${name})`
      host.uploads->Dict.set(name, copyOf(file))
      bytesOf(file)
      ->Promise.thenResolve(bytes => channel.send({"stores": name, "bytes": bytes}->Obj.magic))
      ->ignore
      later(() =>
        View.doc(state).atoms
        ->Dict.toArray
        ->Array.find(((_, atom)) => atom.value == JSON.String(value))
        ->Option.forEach(((id, _)) => state.selected = Some(id))
      , 0)->ignore
      Some(({format: Editor.Page.imageFormat, value: JSON.String(value), uses: []}: View.pasted))
    } else {
      None
    }
  )
  // The file's headings, set again at each change of a heading: the
  // parts that read them draw again.
  React.useEffect0(() =>
    outline->Option.map(outline => {
      let stops = Tilia.watch(() => View.doc(state), doc => {
        let headings = Outline.raws(doc)
        if outline.files->Dict.get(path) != Some(headings) {
          outline.files->Dict.set(path, headings)
        }
      })
      () => stops()
    })
  )
  let (editable, setEditable) = React.useState(() => false)
  React.useEffect0(() => {
    setEditable(_ => true)
    None
  })
  React.useEffect0(() =>
    channel->Option.map(channel => {
      // One save at a time, on the version the page holds.
      let save = () => {
        let text = notes.text()
        if text != held.written && held.sending == None {
          held.sending = Some(text)
          channel.send({"saves": path, "on": held.version, "text": text}->Obj.magic)
        }
      }
      held.save = save
      channel.opens(path, held.version)
      // A file that landed: the engine merges it with what the person
      // typed, and gives the merged text when it differs.
      // The base is the text the server held before: a save it refused
      // keeps its words.
      let lands = (~version, ~text) => {
        let base = held.written
        held.version = version
        held.written = text
        held.sending = None
        notes.land(text, ~base)
      }
      let unheard = channel->Channel.listen(json => {
        let message = heard(json)
        switch message {
        | {saved, version} if saved == path =>
          held.sending->Option.forEach(text => held.written = text)
          held.sending = None
          held.version = version
          save()
        | {file, version, text} if file == path => lands(~version, ~text)
        | {stale, version, text} if stale == path => lands(~version, ~text)
        // A pasted image is stored: under the name the page asked, or
        // under another when two pages asked for one name.
        | {stored, as_} =>
          if stored != as_ {
            let from = JSON.String(`![](${stored})`)
            View.act(state, storage, doc => {
              ...doc,
              atoms: doc.atoms->Dict.mapValues(atom =>
                atom.value == from ? {...atom, value: JSON.String(`![](${as_})`)} : atom
              ),
            })
          }
          host.uploads->Dict.delete(stored)
        | {refused, reason} =>
          renaming->Dict.get(refused)->Option.forEach(answer => {
            renaming->Dict.delete(refused)
            answer(Some(reason))
          })
        | {images} =>
          renaming
          ->Dict.toArray
          ->Array.filter(((name, _)) => images->Array.includes(name))
          ->Array.forEach(((name, answer)) => {
            renaming->Dict.delete(name)
            answer(None)
          })
        | _ => ()
        }
      })
      // Before a reload: save now, and wait until the server holds the
      // page's text, for three seconds at most.
      let unasked = channel->Channel.beforeReload(async () => {
        notes.flush()
        save()
        let tries = ref(0)
        while (held.sending != None || notes.text() != held.written) && tries.contents < 60 {
          tries := tries.contents + 1
          await Promise.make((resolve, _) => later(() => resolve(), 50)->ignore)
        }
      })
      // The file leaves the page: its waiting text is saved first.
      () => {
        notes.close()
        unheard()
        unasked()
      }
    })
  )
  <View state storage editable prefix kinds=notes.kinds ?paste />
}
