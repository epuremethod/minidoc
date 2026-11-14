// The island of `<article>`: the page's markdown as the editor's view. It
// is drawn with editing off, on the server and at hydration, so the two
// give the same HTML; editing turns on once the page has hydrated.
//
// With a channel, the page saves 300 ms after the last key, on the version
// it holds, and a file that lands is merged with what the person typed.
//
// A block that the editor does not read itself, such as a quote or a
// `:::` drawing, is an atom of the editor's markdown format, drawn by the
// blocks, as live draws it.

module View = TiliaEditor.View
module Rule = TiliaEditor.Rule
module Live = MinidocLive.Live

/** The blocks' options: the croquis has no site of its own yet. */
let options: MinidocBlocks.Blocks.options = {}

/** The callouts of the blocks, which the editor draws itself. */
let kinds = MinidocBlocks.Blocks.callouts(options)
let kindNames = kinds->Array.map(((kind, _)) => kind)
let blocks = MinidocBlocks.Blocks.keys(options)->Array.map(key => (key, Editor.Page.format))->Dict.fromArray

/** The page's markdown, read as the editor reads it. */
let read = (text: string) => Land.read(text, ~kinds=kindNames, ~blocks)

/** A block of the editor's markdown format, drawn by the blocks; an image, drawn by minidoc. */
let rules = (host: Picture.host) => Dict.fromArray([
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
@val external cancel: timer => unit = "clearTimeout"

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

/** The name of the next image pasted into the page `path`: `images/notes-1.png`. */
let nameFor = (host: Picture.host, ~path: string, ~extension: string) => {
  let stem = Site.stem(path)
  let rec next = number => {
    let name = `${Site.imagesFolder}${stem}-${Int.toString(number)}.${extension}`
    host.site.images->Array.includes(name) || host.uploads->Dict.has(name) ? next(number + 1) : name
  }
  next(1)
}
external heard: JSON.t => heard = "%identity"

/** What the page holds of its file, and of the sync. */
type held = {
  /** The file as last read: its kept lines write a block nobody changed with its own bytes. */
  mutable file: Editor.Page.t,
  /** The section the page and the server last agreed on: the base of a merge. */
  mutable agreed: Editor.Section.t,
  mutable version: int,
  /** The text the server holds. */
  mutable written: string,
  /** A save sent and not answered yet: its text and its section. */
  mutable sending: option<(string, Editor.Section.t)>,
  mutable minted: int,
}

@react.component
let make = (
  ~site: Site.t,
  ~path: string,
  ~text: string,
  ~version: int,
  ~channel: option<Channel.t>=?,
  ~outline: option<Outline.t>=?,
) => {
  // The renames asked and not answered yet: their answer, by the new name.
  let renaming: dict<option<string> => unit> = React.useMemo0(() => Dict.make())
  let host: Picture.host = React.useMemo0(() => {
    Picture.site,
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
  let held = React.useMemo0(() => {
    let file = read(text)
    {file, agreed: file.section, version, written: text, sending: None, minted: 0}
  })
  let storage: Editor.Section.storage = React.useMemo0(() => {
    Editor.Section.sections: [],
    update: _ => (),
    merge: (~base as _, ~local, ~remote) => Land.merge(~base=held.agreed, ~local, ~remote),
  })
  let state = React.useMemo0(() => View.prepare(held.file.section, ~rules=rules(host)))
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
  // The page's headings, set again at each change of a heading: the
  // parts that read them draw again.
  React.useEffect0(() =>
    outline->Option.map(outline => {
      let stops = Tilia.watch(() => View.doc(state), doc => {
        let headings = Outline.of_(doc)
        if headings != outline.headings {
          outline.headings = headings
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
      let section = () => Editor.Storage.write(View.doc(state), ~id="page")
      let current = () => Editor.Page.write(held.file, section())
      let waiting = ref(None)
      let save = () => {
        let text = current()
        if text != held.written && held.sending == None {
          held.sending = Some((text, section()))
          channel.send({"saves": path, "on": held.version, "text": text}->Obj.magic)
        }
      }
      let soon = () => {
        waiting.contents->Option.forEach(cancel)
        waiting := Some(later(save, 300))
      }
      // A file that landed: merged with what the person typed since the
      // last agreement, then saved again if the page still differs.
      let lands = (~version, ~text) => {
        let file = Land.against(
          text,
          ~base=held.agreed,
          ~mint=() => {
            held.minted = held.minted + 1
            `l${Int.toString(held.minted)}`
          },
          ~kinds=kindNames,
          ~blocks,
        )
        View.land(state, storage, file.section)->ignore
        held.file = file
        held.agreed = file.section
        held.version = version
        held.written = text
        held.sending = None
        if current() != text {
          soon()
        }
      }
      channel->Channel.listen(json => {
        let message = heard(json)
        switch message {
        | {saved, version} if saved == path =>
          held.sending->Option.forEach(((text, section)) => {
            held.written = text
            held.agreed = section
          })
          held.sending = None
          held.version = version
          if current() != held.written {
            soon()
          }
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
      channel->Channel.beforeReload(async () => {
        waiting.contents->Option.forEach(cancel)
        save()
        let tries = ref(0)
        while (held.sending != None || current() != held.written) && tries.contents < 60 {
          tries := tries.contents + 1
          await Promise.make((resolve, _) => later(() => resolve(), 50)->ignore)
        }
      })
      let stops = Tilia.watch(() => View.doc(state), _ => soon())
      () => stops()
    })
  )
  <View state storage editable kinds ?paste />
}
