// A folder of markdown files, as the croquis reads it: each `.md` file is a
// page, in the order of the file names. Nothing here reads a disk: a folder
// is its file names and their texts, so the scenarios run in memory.

type file = {version: int, text: string}

type page = {
  /** The markdown file, as the folder names it. */
  file: string,
  /** The HTML file the page is written to. */
  href: string,
  /** The text of the file's first heading, or the file's name. */
  title: string,
}

type t = {
  files: dict<file>,
  /** The pages, which the sync sets again when a title or a file changes. */
  mutable pages: array<page>,
  /** The images of the `images/` folder, by their path, in order. */
  mutable images: array<string>,
  /** The version of each image that changed on disk since `dev` started: a page draws it again. */
  versions: dict<int>,
}

let isMarkdown = (name: string) => name->String.endsWith(".md")

/** The folder of the images. */
let imagesFolder = "images/"

/** An image of the `images/` folder, by its path: one level down, with an image's extension. */
let isImage = (path: string) =>
  path->String.startsWith(imagesFolder) &&
  !(path->String.slice(~start=String.length(imagesFolder))->String.includes("/")) &&
  RegExp.test(/\.(png|jpe?g|gif|webp|svg|avif)$/i, path)

/** The folder of the site's own components. */
let componentsFolder = "components/"

/** A component of the site: a `.jsx` or `.js` file of `components/`, one level down. */
let isComponent = (path: string) =>
  path->String.startsWith(componentsFolder) &&
  !(path->String.slice(~start=String.length(componentsFolder))->String.includes("/")) &&
  RegExp.test(/\.(jsx|js)$/, path)

let stem = (name: string) => name->String.slice(~start=0, ~end=-3)

let heading = /^#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$/

/** The text of the first heading outside a fence, or none. */
let headingOf = (text: string): option<string> => {
  let fenced = ref(false)
  text
  ->String.split("\n")
  ->Array.findMap(line =>
    if RegExp.test(/^(`{3,}|~{3,})/, line) {
      fenced := !fenced.contents
      None
    } else if fenced.contents {
      None
    } else {
      RegExp.exec(heading, line)->Option.flatMap(found =>
        found->RegExp.Result.matches->Array.get(0)->Option.flatMap(x => x)
      )
    }
  )
}

let pageOf = (name: string, text: string): page => {
  file: name,
  href: stem(name) ++ ".html",
  title: headingOf(text)->Option.getOr(stem(name)),
}

/** The images of a folder, in order. */
let imagesOf = (folder: dict<string>) => folder->Dict.keysToArray->Array.filter(isImage)->Array.toSorted(String.compare)

/** The site of a folder: its markdown files, each at version 1, its pages, and its images. */
let read = (folder: dict<string>): result<t, string> => {
  let names = folder->Dict.keysToArray->Array.filter(isMarkdown)->Array.toSorted(String.compare)
  if names->Array.length == 0 {
    Error("the folder holds no markdown file")
  } else {
    Ok({
      files: names
      ->Array.map(name => (name, {version: 1, text: folder->Dict.getUnsafe(name)}))
      ->Dict.fromArray,
      pages: names->Array.map(name => pageOf(name, folder->Dict.getUnsafe(name))),
      images: imagesOf(folder),
      versions: Dict.make(),
    })
  }
}

/** The page written to `href`, if the site has one. */
let pageAt = (site: t, href: string) => site.pages->Array.find(page => page.href == href)
