// The sync of a folder with its open pages, on the server's side. Each
// markdown file is held at a version, and each open page names the file it
// shows. Three events change it: a page opens a file, a page saves, and a
// file changes on disk. Each answers the messages to send. Nothing here
// reads a disk or a socket: `serve.mjs` wires both.

type file = Site.file

/** Where a message goes: the disk, one page, or every open page. */
type to = Disk | Page(string) | All

type message =
  | Writes({path: string, text: string})
  | Saved({path: string, version: int})
  | File({path: string, version: int, text: string})
  | Stale({path: string, version: int, text: string})
  | Pages(array<Site.page>)
  | Gone(string)
  | Refused({path: string, reason: string})
  /** The template or a component changed: each page reloads once its edits are saved. */
  | Reloads(string)
  /** An image's bytes, in base64, to write at `path`. */
  | Stores({path: string, bytes: string})
  /** The image a page asked to store, and the path it took. */
  | Stored({asked: string, path: string})
  /** A file to move. */
  | Moves({from: string, path: string})
  /** The images of the folder. */
  | Images(array<string>)
  /** An image changed on disk, at its new version. */
  | Image({path: string, version: int})

type sent = {to: to, message: message}

type t = {
  files: dict<file>,
  /** The file each open page shows, by page. */
  shows: dict<string>,
  /** The folder's `index.html`, when it has one. */
  mutable template: option<string>,
  /** The text of each component of `components/`. */
  components: dict<string>,
  /** The images of `images/`, each at its version. */
  images: dict<int>,
  /** The images `dev` wrote or moved itself: the watcher sees them once more, and they send nothing. */
  own: Set.t<string>,
}

/** The folder at the start: each markdown file at version 1. */
let make = (folder: dict<string>): t => {
  files: folder
  ->Dict.toArray
  ->Array.filter(((name, _)) => Site.isMarkdown(name))
  ->Array.map(((name, text)) => (name, ({version: 1, text}: file)))
  ->Dict.fromArray,
  shows: Dict.make(),
  template: folder->Dict.get(Render.templateFile),
  components: folder->Dict.toArray->Array.filter(((name, _)) => Site.isComponent(name))->Dict.fromArray,
  images: Site.imagesOf(folder)->Array.map(path => (path, 1))->Dict.fromArray,
  own: Set.make(),
}

/** The images of the folder, in order. */
let images = (sync: t) => sync.images->Dict.keysToArray->Array.toSorted(String.compare)

/** The images to every page. */
let listed = (sync: t) => {to: All, message: Images(images(sync))}

/** The pages of the folder, in the order of the file names. */
let pages = (sync: t): array<Site.page> =>
  sync.files
  ->Dict.keysToArray
  ->Array.toSorted(String.compare)
  ->Array.map(name => Site.pageOf(name, (sync.files->Dict.getUnsafe(name)).text))

/** The site as it stands, for a page drawn now. An image at its first version needs no version. */
let site = (sync: t): Site.t => {
  files: sync.files,
  pages: pages(sync),
  images: images(sync),
  versions: sync.images->Dict.toArray->Array.filter(((_, version)) => version > 1)->Dict.fromArray,
}

/** A file of the folder that a page may write: a markdown file, by its name alone. */
let writable = (path: string) =>
  Site.isMarkdown(path) && !(path->String.includes("/")) && !(path->String.includes("\\"))

/** The other pages that show `path`. */
let showing = (sync: t, path: string, ~but: option<string>=?) =>
  sync.shows
  ->Dict.toArray
  ->Array.filter(((page, shown)) => shown == path && Some(page) != but)
  ->Array.map(((page, _)) => page)
  ->Array.toSorted(String.compare)

/** The pages to every page, when a title, or the list of files, changed. */
let titles = (before: array<Site.page>, after: array<Site.page>) =>
  before->Array.map(page => (page.href, page.title)) == after->Array.map(page => (page.href, page.title))
    ? []
    : [{to: All, message: Pages(after)}]

/** A page opens the file it shows, on the version it holds: an older one gets the file that stands. */
let opens = (sync: t, ~page: string, ~path: string, ~on: int): array<sent> => {
  sync.shows->Dict.set(page, path)
  switch sync.files->Dict.get(path) {
  | Some(file) if file.version != on => [{to: Page(page), message: File({path, version: file.version, text: file.text})}]
  | _ => []
  }
}

let closes = (sync: t, ~page: string) => sync.shows->Dict.delete(page)

let saves = (sync: t, ~page: string, ~path: string, ~on: int, ~text: string): array<sent> =>
  switch (writable(path), sync.files->Dict.get(path)) {
  | (true, Some(file)) if file.version != on => [
      {to: Page(page), message: Stale({path, version: file.version, text: file.text})},
    ]
  | (true, Some(file)) if file.text == text => [{to: Page(page), message: Saved({path, version: file.version})}]
  | (true, Some(file)) =>
    let before = pages(sync)
    let version = file.version + 1
    sync.files->Dict.set(path, {version, text})
    [{to: Disk, message: Writes({path, text})}, {to: Page(page), message: Saved({path, version})}]
    ->Array.concat(
      showing(sync, path, ~but=page)->Array.map(other => {
        to: Page(other),
        message: File({path, version, text}),
      }),
    )
    ->Array.concat(titles(before, pages(sync)))
  | _ => [
      {
        to: Page(page),
        message: Refused({path, reason: `${path} is not a markdown file of the folder`}),
      },
    ]
  }

// ── Images ──────────────────────────────────────────────────────────────

/** The next name free for an image: `images/a-1.png`, then `images/a-2.png`. */
let free = (sync: t, path: string) => {
  let numbered = RegExp.exec(/^(.*?)-(\d+)(\.[^.\/]+)$/, path)
  let (stem, first, extension) = switch numbered {
  | Some(found) =>
    let part = index => found->RegExp.Result.matches->Array.getUnsafe(index)->Option.getOr("")
    (part(0), part(1)->Int.fromString->Option.getOr(1), part(2))
  | None =>
    let dot = path->String.lastIndexOf(".")
    (path->String.slice(~start=0, ~end=dot), 1, path->String.slice(~start=dot))
  }
  let rec next = number => {
    let name = `${stem}-${Int.toString(number)}${extension}`
    sync.images->Dict.has(name) ? next(number + 1) : name
  }
  sync.images->Dict.has(path) ? next(first + 1) : path
}

let notImage = (page, path) => [
  {to: Page(page), message: Refused({path, reason: `${path} is not an image of the images folder`})},
]

/** A page stores a pasted image: under the name it asks, or the next one free. */
let stores = (sync: t, ~page: string, ~path: string, ~bytes: string): array<sent> =>
  if !Site.isImage(path) {
    notImage(page, path)
  } else {
    let stored = free(sync, path)
    sync.images->Dict.set(stored, 1)
    sync.own->Set.add(stored)
    [
      {to: Disk, message: Stores({path: stored, bytes})},
      {to: Page(page), message: Stored({asked: path, path: stored})},
      listed(sync),
    ]
  }

let escaped = (text: string) => text->String.replaceRegExp(/[.*+?^${}()|[\]\\]/g, "\\$&")

/** A rename: the image moves, and every page that links it is written again. */
let renames = (sync: t, ~page: string, ~path: string, ~as_: string): array<sent> =>
  if !Site.isImage(path) || !(sync.images->Dict.has(path)) {
    notImage(page, path)
  } else if !Site.isImage(as_) {
    notImage(page, as_)
  } else if sync.images->Dict.has(as_) {
    [{to: Page(page), message: Refused({path: as_, reason: `${as_} is already an image of the folder`})}]
  } else {
    let version = sync.images->Dict.getUnsafe(path)
    sync.images->Dict.delete(path)
    sync.images->Dict.set(as_, version)
    sync.own->Set.add(path)
    sync.own->Set.add(as_)
    // A link is the path in parentheses, alone or before a title.
    let link = RegExp.fromString(`\\]\\(${escaped(path)}(?=[)\\s])`, ~flags="g")
    let written =
      sync.files
      ->Dict.keysToArray
      ->Array.toSorted(String.compare)
      ->Array.flatMap(name => {
        let file = sync.files->Dict.getUnsafe(name)
        let text = file.text->String.replaceRegExp(link, `](${as_}`)
        if text == file.text {
          []
        } else {
          let version = file.version + 1
          sync.files->Dict.set(name, {version, text})
          [{to: Disk, message: Writes({path: name, text})}]->Array.concat(
            showing(sync, name)->Array.map(other => {
              to: Page(other),
              message: File({path: name, version, text}),
            }),
          )
        }
      })
    [{to: Disk, message: Moves({from: path, path: as_})}]->Array.concat(written)->Array.concat([listed(sync)])
  }

/** An image changed on disk: `None` when it was removed. */
let imageChanged = (sync: t, ~path: string, ~there: bool): array<sent> =>
  if sync.own->Set.has(path) {
    sync.own->Set.delete(path)->ignore
    []
  } else {
    switch (sync.images->Dict.get(path), there) {
    | (Some(version), true) =>
      sync.images->Dict.set(path, version + 1)
      [{to: All, message: Image({path, version: version + 1})}]
    | (None, true) =>
      sync.images->Dict.set(path, 1)
      [listed(sync)]
    | (Some(_), false) =>
      sync.images->Dict.delete(path)
      [listed(sync)]
    | (None, false) => []
    }
  }

/** A file changed on disk: `None` when it was removed. */
let changed = (sync: t, ~path: string, ~text: option<string>): array<sent> =>
  if Site.isImage(path) {
    imageChanged(sync, ~path, ~there=text != None)
  } else if Site.isComponent(path) {
    if sync.components->Dict.get(path) == text {
      []
    } else {
      switch text {
      | Some(text) => sync.components->Dict.set(path, text)
      | None => sync.components->Dict.delete(path)
      }
      [{to: All, message: Reloads(path)}]
    }
  } else if path == Render.templateFile {
    if sync.template == text {
      []
    } else {
      sync.template = text
      [{to: All, message: Reloads(path)}]
    }
  } else if !writable(path) {
    []
  } else {
    let before = pages(sync)
    switch (sync.files->Dict.get(path), text) {
    | (Some(file), Some(text)) if file.text == text => []
    | (Some(file), Some(text)) =>
      let version = file.version + 1
      sync.files->Dict.set(path, {version, text})
      showing(sync, path)
      ->Array.map(page => {to: Page(page), message: File({path, version, text})})
      ->Array.concat(titles(before, pages(sync)))
    | (None, Some(text)) =>
      sync.files->Dict.set(path, {version: 1, text})
      titles(before, pages(sync))
    | (Some(_), None) =>
      sync.files->Dict.delete(path)
      showing(sync, path)
      ->Array.map(page => {to: Page(page), message: Gone(path)})
      ->Array.concat(titles(before, pages(sync)))
    | (None, None) => []
    }
  }

// ── The wire ────────────────────────────────────────────────────────────

/** A message as JSON, as the page reads it. */
let wire = (message: message): JSON.t =>
  switch message {
  | Writes({path, text}) => {"writes": path, "text": text}->Obj.magic
  | Saved({path, version}) => {"saved": path, "version": version}->Obj.magic
  | File({path, version, text}) => {"file": path, "version": version, "text": text}->Obj.magic
  | Stale({path, version, text}) => {"stale": path, "version": version, "text": text}->Obj.magic
  | Pages(pages) => {"pages": pages}->Obj.magic
  | Gone(path) => {"gone": path}->Obj.magic
  | Refused({path, reason}) => {"refused": path, "reason": reason}->Obj.magic
  | Reloads(path) => {"reloads": path}->Obj.magic
  | Stores({path, bytes}) => {"stores": path, "bytes": bytes}->Obj.magic
  | Stored({asked, path}) => {"stored": asked, "as": path}->Obj.magic
  | Moves({from, path}) => {"moves": from, "as": path}->Obj.magic
  | Images(images) => {"images": images}->Obj.magic
  | Image({path, version}) => {"image": path, "version": version}->Obj.magic
  }

/** Where a message goes, as a word: "disk", "all", or the page. */
let where = (to: to) =>
  switch to {
  | Disk => "disk"
  | All => "all"
  | Page(page) => page
  }
