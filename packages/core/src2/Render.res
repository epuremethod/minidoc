// A page of the site, written into its template: the folder's `index.html`,
// or minidoc's own. The template is HTML; each element that names a
// component in `data-component` is a part, drawn by its component, and
// `<nav>` is `menu` when it names none: the folder's component of that name,
// or minidoc's. A name that neither has is refused. `<article>` must be
// there: the page has no place without it. The `<title>` takes the page's
// title. minidoc's stylesheets go first in the head, so the template's own
// win. The page carries, as JSON, the files its render read and the pages,
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
  files: dict<Site.file>,
  pages: array<Site.page>,
  images: array<string>,
  versions: dict<int>,
  /** The page's headings, as the article reads them: the parts hydrate with them. */
  headings: array<Outline.heading>,
}

/** The id of the script that holds what a page carries. */
let dataId = "minidoc-data"

/** JSON in a script: a `<` would end it. */
let scriptJson = (value: carried) =>
  JSON.stringifyAny(value)->Option.getOr("{}")->String.replaceAll("<", "\\u003c")

/** The template's file in the folder. */
let templateFile = "index.html"

/** minidoc's stylesheets, first in every page: the blocks', their theme, and the editor's. */
let sheets = ["./__minidoc/blocks.css", "./__minidoc/soft.css", "./__minidoc/editor.css"]

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

/** The headings of a page's markdown, as the article reads them. */
let headingsOf = (text: string) => Outline.of_(Editor.Storage.read(Article.read(text).section))

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
  switch document->querySelector("article")->Nullable.toOption {
  | None => Error(`${templateFile} has no <article>: the page has no place in it`)
  | Some(article) =>
    let file = site.files->Dict.getUnsafe(page.file)
    let headings = headingsOf(file.text)
    let outline: Outline.t = {headings: headings}
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
    parts->Array.forEach(((element, _, component)) =>
      component->Option.forEach(component =>
        element->setInnerHTML(
          ReactDOMServer.renderToString(<Part component site current=page.href outline />),
        )
      )
    )
    article->setAttribute("data-minidoc", "article")
    article->setInnerHTML(
      ReactDOMServer.renderToString(<Article site path=page.file text=file.text version=file.version />),
    )
    if document->querySelector("title")->Nullable.isNullable {
      document->head->append(document->createElement("title"))
    }
    document->setTitle(page.title)
    sheets
    ->Array.toReversed
    ->Array.forEach(href => {
      let link = document->createElement("link")
      link->setAttribute("rel", "stylesheet")
      link->setAttribute("href", href)
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
        files: Dict.fromArray([(page.file, site.files->Dict.getUnsafe(page.file))]),
        pages: site.pages,
        images: site.images,
        versions: site.versions,
        headings,
      }),
    )
    document->body->append(data)
    if live {
      let client = document->createElement("script")
      client->setAttribute("type", "module")
      client->setAttribute("src", "./__minidoc/client.js")
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
