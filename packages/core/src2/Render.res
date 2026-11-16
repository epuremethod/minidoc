// A page of the site, written into its template: the folder's `index.html`,
// or minidoc's own. The template is HTML; each element that names a
// component in `data-component` is a part, drawn by its component, and
// `<nav>` is `menu` when it names none: the folder's component of that name,
// or minidoc's. A name that neither has is refused. `<article>` must be
// there: the page has no place without it. The `<title>` takes the page's
// title. minidoc's stylesheets go first in the head, so the template's own
// win. A page in a sub-folder gets them, and the template's own links,
// relative to it. An element with `data-front` shows that key of the page's
// frontmatter, and each `<meta name="callout">` names a callout of the
// site. The page carries, as JSON, the files its render read and the pages,
// so that it hydrates with the values the server had.

type document
type element
type parsed = {document: document}

@module("linkedom") external parseHTML: string => parsed = "parseHTML"
@send external querySelector: (document, string) => Nullable.t<element> = "querySelector"
@send external querySelectorAll: (document, string) => array<element> = "querySelectorAll"
@send external createElement: (document, string) => element = "createElement"
@get external body: document => element = "body"
@get external head: document => element = "head"
@get external documentElement: document => element = "documentElement"
@send external prepend: (element, element) => unit = "prepend"
@get external textContent: element => string = "textContent"
@send external getAttribute: (element, string) => Nullable.t<string> = "getAttribute"
@set external setTitle: (document, string) => unit = "title"
@set external setInnerHTML: (element, string) => unit = "innerHTML"
@set external setTextContent: (element, string) => unit = "textContent"
@send external setAttribute: (element, string, string) => unit = "setAttribute"
@send external append: (element, element) => unit = "append"
@send external toString: document => string = "toString"

/** What a page carries for its hydration. */
type carried = {
  current: string,
  /** The way from the page to the folder: nothing, or `../` for each folder down. */
  root: string,
  /** The page's file and each section's. */
  files: dict<Site.file>,
  pages: array<Site.page>,
  images: array<string>,
  versions: dict<int>,
  /** The page's headings, as the parts draw them. */
  headings: array<Outline.heading>,
  /** The headings of each file, as its editor reads them: the parts hydrate with them. */
  outline: dict<array<Outline.raw>>,
  /** The callouts the template names, by name with their label. */
  callouts: dict<string>,
}

/** The id of the script that holds what a page carries. */
let dataId = "minidoc-data"

/** JSON in a script: a `<` would end it. */
let scriptJson = (value: carried) =>
  JSON.stringifyAny(value)->Option.getOr("{}")->String.replaceAll("<", "\\u003c")

/** The template's file in the folder. */
let templateFile = "index.html"

/** minidoc's stylesheets, first in every page: the blocks', their theme, and the editor's. */
let sheets = ["__minidoc/blocks.css", "__minidoc/soft.css", "__minidoc/editor.css"]

/** A link of the template that is relative to the folder: no scheme, no `/` first, not a place in the page. */
let fromFolder = (link: string) => link != "" && !RegExp.test(/^([a-z][a-z0-9+.-]*:|\/|#|\?)/i, link)

/** The attribute that names a key of the frontmatter. */
let frontAttribute = "data-front"

/**
 The callouts a template names: `<meta name="callout" content="pro Pro tip">`,
 the name and then its label. A name that is a block of minidoc is refused.
*/
let calloutsOf = (document: document): result<dict<string>, string> => {
  let blocks = MinidocBlocks.Blocks.keys({})
  let named =
    document
    ->querySelectorAll(`meta[name="callout"]`)
    ->Array.filterMap(meta => {
      let content = meta->getAttribute("content")->Nullable.toOption->Option.getOr("")->String.trim
      switch RegExp.exec(/^(\S+)\s*([\s\S]*)$/, content) {
      | Some(found) =>
        let part = index => found->RegExp.Result.matches->Array.get(index)->Option.flatMap(x => x)->Option.getOr("")
        Some((part(0), part(1) == "" ? part(0) : part(1)))
      | None => None
      }
    })
  switch named->Array.find(((name, _)) => blocks->Array.includes(name)) {
  | Some((name, _)) => Error(`${templateFile} names the callout "${name}", which is a block of minidoc`)
  | None => Ok(Dict.fromArray(named))
  }
}

/** The theme of the blocks' drawings, when the template names none. */
let theme = "soft"

/** The components minidoc gives, by name. */
let builtin: dict<Part.component> = Dict.fromArray([
  ("contents", Contents.make),
  (Part.menu, Menu.make),
  ("pager", Pager.make),
])

/** A component by its name: the folder's, or minidoc's. */
let componentOf = (components: dict<Part.component>, name: string) =>
  switch components->Dict.get(name) {
  | Some(component) => Some(component)
  | None => builtin->Dict.get(name)
  }

/** The headings of a file's markdown, as its editor reads them. */
let headingsOf = (kit: Article.kit, text: string) => Outline.raws(Editor.Storage.read(Article.read(kit, text).section))

/**
 The HTML of `page`, in `template`. With `live`, the page loads the
 client that hydrates its islands.
*/
let page = (
  site: Site.t,
  page: Site.page,
  ~template: string,
  ~live: bool,
  ~components: dict<Part.component>=Dict.make(),
): result<string, string> => {
  let {document} = parseHTML(template)
  switch (document->querySelector("article")->Nullable.toOption, calloutsOf(document)) {
  | (None, _) => Error(`${templateFile} has no <article>: the page has no place in it`)
  | (_, Error(message)) => Error(message)
  | (Some(article), Ok(callouts)) =>
    let kit = Article.kitOf(callouts)
    let root = Site.rootOf(page.href)
    let files =
      [page.file]
      ->Array.concat(page.sections->Array.map(section => section.file))
      ->Array.map(name => (name, site.files->Dict.getUnsafe(name)))
      ->Dict.fromArray
    let outline: Outline.t = {files: files->Dict.mapValues(file => headingsOf(kit, file.text))}
    // A page in a sub-folder: each link of the template leads from the page.
    if root != "" {
      ["href", "src"]->Array.forEach(name =>
        document
        ->querySelectorAll(`[${name}]`)
        ->Array.forEach(element =>
          element
          ->getAttribute(name)
          ->Nullable.toOption
          ->Option.forEach(link =>
            if fromFolder(link) {
              element->setAttribute(name, root ++ link->String.replaceRegExp(/^\.\//, ""))
            }
          )
        )
      )
    }
    // `<nav>` is `menu` when it names no component.
    document
    ->querySelector("nav")
    ->Nullable.toOption
    ->Option.forEach(nav =>
      if nav->getAttribute(Part.attribute)->Nullable.isNullable {
        nav->setAttribute(Part.attribute, Part.menu)
      }
    )
    let parts =
      document
      ->querySelectorAll(`[${Part.attribute}]`)
      ->Array.map(element => {
        let name = element->getAttribute(Part.attribute)->Nullable.toOption->Option.getOr("")
        (element, name, componentOf(components, name))
      })
    switch parts->Array.find(((_, _, component)) => component->Option.isNone) {
    | Some((_, name, _)) =>
      Error(`${templateFile} names the component "${name}", which neither minidoc nor components/ has`)
    | None =>
    // A text, a number or a yes or no of the frontmatter shows; else the element keeps what the template wrote.
    document
    ->querySelectorAll(`[${frontAttribute}]`)
    ->Array.forEach(element =>
      element
      ->getAttribute(frontAttribute)
      ->Nullable.toOption
      ->Option.flatMap(key => page.front->Dict.get(key))
      ->Option.flatMap(Site.scalar)
      ->Option.forEach(text => element->setTextContent(text))
    )
    parts->Array.forEach(((element, _, component)) =>
      component->Option.forEach(component =>
        element->setInnerHTML(
          ReactDOMServer.renderToString(<Part component site current=page.href outline />),
        )
      )
    )
    article->setAttribute("data-minidoc", "article")
    article->setInnerHTML(ReactDOMServer.renderToString(<Body site current=page.href kit root />))
    if document->querySelector("title")->Nullable.isNullable {
      document->head->append(document->createElement("title"))
    }
    document->setTitle(page.title)
    let lead = root == "" ? "./" : root
    sheets
    ->Array.toReversed
    ->Array.forEach(href => {
      let link = document->createElement("link")
      link->setAttribute("rel", "stylesheet")
      link->setAttribute("href", lead ++ href)
      document->head->prepend(link)
    })
    if document->querySelector("[data-blocks-theme]")->Nullable.isNullable {
      document->documentElement->setAttribute("data-blocks-theme", theme)
    }
    let data = document->createElement("script")
    data->setAttribute("type", "application/json")
    data->setAttribute("id", dataId)
    data->setTextContent(
      scriptJson({
        current: page.href,
        root,
        files,
        pages: site.pages,
        images: site.images,
        versions: site.versions,
        headings: Outline.page(page, outline.files),
        outline: outline.files,
        callouts,
      }),
    )
    document->body->append(data)
    if live {
      let client = document->createElement("script")
      client->setAttribute("type", "module")
      client->setAttribute("src", lead ++ "__minidoc/client.js")
      document->body->append(client)
    }
    Ok(document->toString)
    }
  }
}

/** Every page of a folder, by the HTML file it is written to, in the folder's template or in `template`. */
let folder = (
  folder: dict<string>,
  ~template: string,
  ~live=false,
  ~components: dict<Part.component>=Dict.make(),
): result<dict<string>, string> => {
  let template = folder->Dict.get(templateFile)->Option.getOr(template)
  switch Site.read(folder) {
  | Error(message) => Error(message)
  | Ok(site) =>
    site.pages->Array.reduce(Ok(Dict.make()), (done, one) =>
      switch (done, page(site, one, ~template, ~live, ~components)) {
      | (Ok(pages), Ok(html)) =>
        pages->Dict.set(one.href, html)
        Ok(pages)
      | (Error(message), _) | (_, Error(message)) => Error(message)
      }
    )
  }
}
