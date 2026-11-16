// The island of `<article>`: the page's own file, then each section in an
// element of its own, `<section id="slug">`. Each file is its own editor,
// and saves to its own file. The sections follow the site's pages: a file
// that a glob names shows in its place once the page holds its text.

@react.component
let make = (
  ~site: Site.t,
  ~current: string,
  ~kit: Article.kit,
  ~root: string="",
  ~channel: option<Channel.t>=?,
  ~outline: option<Outline.t>=?,
) => {
  TiliaReact.useTilia()
  let file = (path, ~prefix="") =>
    switch site.files->Dict.get(path) {
    | Some({text, version}) => <Article key=path site kit root path prefix text version ?channel ?outline />
    | None => React.null
    }
  switch site.pages->Array.find(page => page.href == current) {
  | None => React.null
  | Some(page) =>
    <>
      {file(page.file)}
      {page.sections
      ->Array.map(section =>
        <section key=section.file id=section.slug> {file(section.file, ~prefix=Outline.prefix(section))} </section>
      )
      ->React.array}
    </>
  }
}
