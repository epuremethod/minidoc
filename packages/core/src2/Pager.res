// `pager`: a link to the previous page and one to the next, in the menu's
// order. What the default template's `<footer>` gets, so a reader sees
// where a page ends.

let make: Part.component = ({page, pages}) => {
  let at = pages->Array.findIndex(one => one.href == page.href)
  let link = (index, rel) =>
    switch pages->Array.get(index) {
    | Some(one) if at >= 0 =>
      <a href=one.href rel className={"pager__" ++ rel}> {React.string(one.title)} </a>
    | _ => React.null
    }
  <>
    {link(at - 1, "prev")}
    {link(at + 1, "next")}
  </>
}
