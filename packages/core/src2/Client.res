// The page's own code: it reads what the page carries, and hydrates each
// part and the article with the values the server had. `start` takes the
// folder's components, which the bundle hands it. Then the channel keeps the page in
// sync: the article saves and lands its file, and a `pages` message sets
// the site's pages, so the menu draws again and a tilia `observe` keeps
// the document's title on the current page's title.

type element
@val @scope("document") external byId: string => Nullable.t<element> = "getElementById"
@val @scope("document") external select: string => Nullable.t<Dom.element> = "querySelector"
@get external textContent: element => string = "textContent"
type document
@val external document: document = "document"
@set external setTitleOf: (document, string) => unit = "title"
let setTitle = title => document->setTitleOf(title)

external asCarried: JSON.t => Render.carried = "%identity"

/** Each element of the page that `selector` finds. */
let elements: string => array<Dom.element> = %raw(`(selector) => Array.from(document.querySelectorAll(selector))`)
@send external attributeOf: (Dom.element, string) => Nullable.t<string> = "getAttribute"

/**
 A link to a slug leads to its heading: a click on it, a page opened with
 it, or a change of the address's hash. The editor draws a heading with
 its block's id, so the page finds the heading by its slug in the headings.
*/
let follow: (unit => array<Outline.heading>) => unit = %raw(`(headings) => {
  const go = (slug, smooth) => {
    const heading = headings().find((one) => one.slug === slug)
    const element = heading && document.getElementById("block-" + heading.block)
    if (!element) return false
    element.scrollIntoView({ behavior: smooth ? "smooth" : "auto", block: "start" })
    return true
  }
  const slugOf = (hash) => decodeURIComponent(hash.replace(/^#/, ""))
  document.addEventListener("click", (event) => {
    const link = event.target instanceof Element ? event.target.closest('a[href^="#"]') : null
    if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey) return
    if (link.closest("[contenteditable=true]")) return
    const slug = slugOf(link.getAttribute("href"))
    if (go(slug, true)) {
      event.preventDefault()
      history.pushState(null, "", "#" + slug)
    }
  })
  window.addEventListener("hashchange", () => go(slugOf(location.hash), false))
  if (location.hash) requestAnimationFrame(() => go(slugOf(location.hash), false))
}`)

/** The callout that holds the caret has `data-caret`: its empty byline shows, so the person can write an author and a date. */
let markCaret: unit => unit = %raw(`() => {
  let marked = null
  document.addEventListener("selectionchange", () => {
    const node = getSelection()?.anchorNode
    const element = node ? (node.nodeType === 1 ? node : node.parentElement) : null
    const callout = element?.closest("article .callout") ?? null
    if (callout === marked) return
    marked?.removeAttribute("data-caret")
    callout?.setAttribute("data-caret", "")
    marked = callout
  })
}`)

type heard = {
  pages?: array<Site.page>,
  reloads?: string,
  images?: array<string>,
  image?: string,
  version?: int,
}
external heard: JSON.t => heard = "%identity"

let carried =
  byId(Render.dataId)
  ->Nullable.toOption
  ->Option.map(script => script->textContent->JSON.parseOrThrow->asCarried)

let start = (components: dict<Part.component>) =>
  switch carried {
  | None => ()
  | Some({current, files, pages, images, versions, headings}) =>
    let site = Tilia.tilia(({files, pages, images, versions}: Site.t))
    let outline: Outline.t = Tilia.tilia({Outline.headings: headings})
    elements(`[${Part.attribute}]`)->Array.forEach(element =>
      element
      ->attributeOf(Part.attribute)
      ->Nullable.toOption
      ->Option.flatMap(name => Render.componentOf(components, name))
      ->Option.forEach(component =>
        ReactDOM.Client.hydrateRoot(element, <Part component site current outline />)->ignore
      )
    )
    follow(() => outline.headings)
    markCaret()
    pages
    ->Array.find(page => page.href == current)
    ->Option.forEach(page => {
      let file = files->Dict.getUnsafe(page.file)
      let channel = Channel.open_(~path=page.file, ~version=file.version)
      channel->Channel.listen(json =>
        switch heard(json) {
        | {pages} => site.pages = pages
        | {images} => site.images = images
        // An image changed on disk: each page that shows it draws it again.
        | {image, version} => site.versions->Dict.set(image, version)
        // The template or a component changed: the page loads again.
        | {reloads: _} => channel->Channel.reload
        | _ => ()
        }
      )
      select(`[data-minidoc="article"]`)
      ->Nullable.toOption
      ->Option.forEach(element =>
        ReactDOM.Client.hydrateRoot(
          element,
          <Article site path=page.file text=file.text version=file.version channel outline />,
        )->ignore
      )
      Tilia.observe(() =>
        site.pages->Array.find(one => one.href == current)->Option.forEach(one => setTitle(one.title))
      )->ignore
    })
  }
