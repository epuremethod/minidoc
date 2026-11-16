// The page's own code: it reads what the page carries, and hydrates each
// part and the article with the values the server had. `start` takes the
// folder's components, which the bundle hands it. Then the channel keeps
// the page in sync: each file of the article saves and lands, and a `pages`
// message sets the site's pages. So the menu draws again, a section whose
// file is new shows once the page holds its text, and a tilia `observe`
// keeps the document's title and each `data-front` element on the current
// page's values.

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
@set external setText: (Dom.element, string) => unit = "textContent"
@get external text: Dom.element => string = "textContent"

/**
 A link to a slug leads to its heading: a click on it, a page opened with
 it, or a change of the address's hash. The editor draws a heading with
 its block's id, so the page finds the heading by its slug in the headings.
 A section with no heading is the element of that id: the browser leads there.
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
  file?: string,
  text?: string,
  gone?: string,
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
  | Some({current, root, files, pages, images, versions, outline, callouts}) =>
    let site = Tilia.tilia(({files, pages, images, versions}: Site.t))
    let outline: Outline.t = Tilia.tilia({Outline.files: outline})
    let kit = Article.kitOf(callouts)
    let page = () => site.pages->Array.find(page => page.href == current)
    elements(`[${Part.attribute}]`)->Array.forEach(element =>
      element
      ->attributeOf(Part.attribute)
      ->Nullable.toOption
      ->Option.flatMap(name => Render.componentOf(components, name))
      ->Option.forEach(component =>
        ReactDOM.Client.hydrateRoot(element, <Part component site current outline />)->ignore
      )
    )
    follow(() => page()->Option.mapOr([], page => Outline.page(page, outline.files)))
    markCaret()
    if page()->Option.isSome {
      let channel = Channel.open_(~root)
      // The files the page shows: its own and each section's. A file it
      // shows no more leaves it; a file it lacks is asked for, and its
      // section shows when its text comes.
      let follows = () =>
        page()->Option.forEach(page => {
          let named = [page.file]->Array.concat(page.sections->Array.map(section => section.file))
          site.files
          ->Dict.keysToArray
          ->Array.filter(file => !(named->Array.includes(file)))
          ->Array.forEach(file => {
            site.files->Dict.delete(file)
            outline.files->Dict.delete(file)
          })
          named
          ->Array.filter(file => !(site.files->Dict.has(file)))
          ->Array.forEach(file => channel.opens(file, 0))
        })
      channel
      ->Channel.listen(json =>
        switch heard(json) {
        | {pages} =>
          site.pages = pages
          follows()
        // The text of a file the page asked for.
        | {file, version, text} =>
          if !(site.files->Dict.has(file)) {
            site.files->Dict.set(file, {version, text})
          }
        | {gone} =>
          site.files->Dict.delete(gone)
          outline.files->Dict.delete(gone)
        | {images} => site.images = images
        // An image changed on disk: each page that shows it draws it again.
        | {image, version} => site.versions->Dict.set(image, version)
        // The template or a component changed: the page loads again.
        | {reloads: _} => channel->Channel.reload
        | _ => ()
        }
      )
      ->ignore
      select(`[data-minidoc="article"]`)
      ->Nullable.toOption
      ->Option.forEach(element =>
        ReactDOM.Client.hydrateRoot(element, <Body site current kit root channel outline />)->ignore
      )
      Tilia.observe(() => page()->Option.forEach(one => setTitle(one.title)))->ignore
      // Each element that names a key of the frontmatter follows its value.
      Tilia.observe(() =>
        page()->Option.forEach(one =>
          elements(`[${Render.frontAttribute}]`)->Array.forEach(element =>
            element
            ->attributeOf(Render.frontAttribute)
            ->Nullable.toOption
            ->Option.flatMap(key => one.front->Dict.get(key))
            ->Option.flatMap(Site.scalar)
            ->Option.forEach(value =>
              if element->text != value {
                element->setText(value)
              }
            )
          )
        )
      )->ignore
    }
  }
