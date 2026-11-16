// `menu`: a link to each page, by its `nav` or else its title, the current
// one marked. What `<nav>` gets.

let make: Part.component = ({page, pages}) =>
  <ul>
    {pages
    ->Array.map(one =>
      <li key=one.href>
        <a href=one.href ariaCurrent=?{one.href == page.href ? Some(#page) : None}>
          {React.string(one.nav->Option.getOr(one.title))}
        </a>
      </li>
    )
    ->React.array}
  </ul>
