// `menu`: a link to each page, the current one marked. What `<nav>` gets.

let make: Part.component = ({page, pages}) =>
  <ul>
    {pages
    ->Array.map(one =>
      <li key=one.href>
        <a href=one.href ariaCurrent=?{one.href == page.href ? Some(#page) : None}>
          {React.string(one.title)}
        </a>
      </li>
    )
    ->React.array}
  </ul>
