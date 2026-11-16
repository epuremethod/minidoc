// A folder of markdown files, as the croquis reads it: each `.md` file is a
// page, in the order of the file names, unless a page names it as a section
// in `sections` of its frontmatter. Nothing here reads a disk: a folder is
// its file names and their texts, so the scenarios run in memory.

type file = {version: int, text: string}

/** A file that a page names as a section: it is drawn in the page, and is no page of its own. */
type section = {
  /** The markdown file, as the folder names it. */
  file: string,
  /** Its file name without the number and `.md`: the id of its element in the page. */
  slug: string,
  /** The text of the file's first heading, or its slug. */
  title: string,
  /** `nav` of its frontmatter: a short label. */
  nav?: string,
  /** Its frontmatter, as YAML reads it. */
  front: dict<JSON.t>,
}

type page = {
  /** The markdown file, as the folder names it. */
  file: string,
  /** The HTML file the page is written to. */
  href: string,
  /** The text of the file's first heading, or the file's name. */
  title: string,
  /** `nav` of its frontmatter: its name in the menu. */
  nav?: string,
  /** Its frontmatter, as YAML reads it. */
  front: dict<JSON.t>,
  /** The files that `sections` of its frontmatter names, in order. */
  sections: array<section>,
}

type t = {
  files: dict<file>,
  /** The pages, which the sync sets again when a page or a section changes. */
  mutable pages: array<page>,
  /** The images of the `images/` folder, by their path, in order. */
  mutable images: array<string>,
  /** The version of each image that changed on disk since `dev` started: a page draws it again. */
  versions: dict<int>,
}

/** A markdown file at any depth, outside `node_modules` and any folder or file whose name starts with a dot. */
let isMarkdown = (name: string) =>
  name->String.endsWith(".md") &&
  name->String.split("/")->Array.every(part => part != "" && part != "node_modules" && !(part->String.startsWith(".")))

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

/** A file's name without its folders and `.md`. */
let base = (name: string) => stem(name->String.split("/")->Array.at(-1)->Option.getOr(name))

/** The frontmatter of a text with its fences, and the text after it. */
let split = (text: string): (string, string) =>
  switch RegExp.exec(Editor.Frontmatter.fenced, text) {
  | Some(found) =>
    let front = found->RegExp.Result.fullMatch
    (front, text->String.slice(~start=String.length(front)))
  | None => ("", text)
  }

/** The frontmatter of a text, as YAML reads it: empty when it has none, or when it does not read. */
let frontOf = (text: string): dict<JSON.t> => {
  let (front, _) = split(text)
  Editor.Frontmatter.read(front, TiliaEditor.Yaml.encoder)->Option.getOr(Dict.make())
}

/** A value that shows as one text: a text, a number, a yes or no. A list or a map shows nothing. */
let scalar = (value: JSON.t): option<string> =>
  switch value {
  | String(text) => Some(text)
  | Number(number) => Some(Float.toString(number))
  | Boolean(yes) => Some(yes ? "true" : "false")
  | _ => None
  }

let navOf = (front: dict<JSON.t>) => front->Dict.get("nav")->Option.flatMap(scalar)

/** The title of a text: its first heading after the frontmatter, or none. */
let titleOf = (text: string) => {
  let (_, body) = split(text)
  headingOf(body)
}

/** The globs of `sections` in a frontmatter: one, or a list. */
let globsOf = (front: dict<JSON.t>): array<string> =>
  switch front->Dict.get("sections") {
  | Some(String(glob)) => [glob]
  | Some(Array(globs)) =>
    globs->Array.filterMap(glob =>
      switch glob {
      | String(glob) => Some(glob)
      | _ => None
      }
    )
  | _ => []
  }

/** A glob as a pattern: a path from the folder, with `*` for any text in one folder. */
let pattern = (glob: string) =>
  RegExp.fromString(
    "^" ++
    glob
    ->String.replaceRegExp(/^\.\//, "")
    ->String.replaceRegExp(/[.+?^${}()|[\]\\]/g, "\\$&")
    ->String.replaceAll("*", "[^/]*") ++ "$",
  )

/** A section's slug: its file name without its folders, its number and `.md`. */
let slugOf = (name: string) => {
  let whole = base(name)
  let slug = whole->String.replaceRegExp(/^\d+[-_. ]*/, "")
  slug == "" ? whole : slug
}

/** `to_` as a link from the page `from`: `../a.html` from `notes/today.html`. */
let relative = (~from: string, to_: string) => {
  let folder = from->String.split("/")->Array.slice(~start=0, ~end=-1)
  let parts = to_->String.split("/")
  let rec shared = at =>
    at < Array.length(folder) && at < Array.length(parts) - 1 && folder->Array.get(at) == parts->Array.get(at)
      ? shared(at + 1)
      : at
  let common = shared(0)
  "../"->String.repeat(Array.length(folder) - common) ++ parts->Array.slice(~start=common)->Array.join("/")
}

/** The way from a page to the folder: nothing for a page of the folder, `../` for a page one folder down. */
let rootOf = (href: string) => "../"->String.repeat(href->String.split("/")->Array.length - 1)

/**
 The pages of a folder's markdown files, by name with their text, in the
 order of the file names. A file that a page names in `sections` is a
 section of that page, and no page. A file that two pages name is refused.
*/
let pagesOf = (texts: dict<string>): result<array<page>, string> => {
  let names = texts->Dict.keysToArray->Array.filter(isMarkdown)->Array.toSorted(String.compare)
  let fronts = names->Array.map(name => (name, frontOf(texts->Dict.getUnsafe(name))))->Dict.fromArray
  // The files a file names: those of each glob in the order of their names, the globs in turn, each file once.
  let named = name =>
    globsOf(fronts->Dict.getUnsafe(name))->Array.reduce([], (found, glob) => {
      let matches = pattern(glob)
      found->Array.concat(
        names->Array.filter(other => other != name && RegExp.test(matches, other) && !(found->Array.includes(other))),
      )
    })
  let naming = names->Array.filter(name => named(name)->Array.length > 0)
  let taken = Set.fromArray(naming->Array.flatMap(named))
  // A file that names sections and is itself a section names none.
  let heads = naming->Array.filter(name => !(taken->Set.has(name)))
  let owner = Dict.make()
  let shared = ref(None)
  heads->Array.forEach(head =>
    named(head)->Array.forEach(file =>
      switch owner->Dict.get(file) {
      | Some(first) =>
        if shared.contents == None {
          shared := Some(`${file} is a section of ${first} and of ${head}`)
        }
      | None => owner->Dict.set(file, head)
      }
    )
  )
  switch shared.contents {
  | Some(message) => Error(message)
  | None =>
    Ok(
      names
      ->Array.filter(name => !(owner->Dict.has(name)))
      ->Array.map(name => {
        let front = fronts->Dict.getUnsafe(name)
        let slugs = Dict.make()
        let sections = !(heads->Array.includes(name))
          ? []
          : named(name)->Array.map(file => {
              let front = fronts->Dict.getUnsafe(file)
              let slug = slugOf(file)
              // Two files of one page with one slug: `-1` after the second.
              let slug = switch slugs->Dict.get(slug) {
              | None =>
                slugs->Dict.set(slug, 0)
                slug
              | Some(count) =>
                slugs->Dict.set(slug, count + 1)
                `${slug}-${Int.toString(count + 1)}`
              }
              {
                file,
                slug,
                title: titleOf(texts->Dict.getUnsafe(file))->Option.getOr(slug),
                nav: ?navOf(front),
                front,
              }
            })
        {
          file: name,
          href: stem(name) ++ ".html",
          title: titleOf(texts->Dict.getUnsafe(name))->Option.getOr(base(name)),
          nav: ?navOf(front),
          front,
          sections,
        }
      }),
    )
  }
}

/** The images of a folder, in order. */
let imagesOf = (folder: dict<string>) => folder->Dict.keysToArray->Array.filter(isImage)->Array.toSorted(String.compare)

/** The site of a folder: its markdown files, each at version 1, its pages, and its images. */
let read = (folder: dict<string>): result<t, string> => {
  let names = folder->Dict.keysToArray->Array.filter(isMarkdown)->Array.toSorted(String.compare)
  if names->Array.length == 0 {
    Error("the folder holds no markdown file")
  } else {
    pagesOf(folder)->Result.map(pages => {
      files: names
      ->Array.map(name => (name, {version: 1, text: folder->Dict.getUnsafe(name)}))
      ->Dict.fromArray,
      pages,
      images: imagesOf(folder),
      versions: Dict.make(),
    })
  }
}

/** The page written to `href`, if the site has one. */
let pageAt = (site: t, href: string) => site.pages->Array.find(page => page.href == href)
