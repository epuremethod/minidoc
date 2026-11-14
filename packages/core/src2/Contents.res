// `contents`: the page's `##` and `###` headings, each a link to its slug,
// each `###` in a list under the `##` before it. The `#` heading is the
// page's title, and is not in the contents.

let link = (heading: Part.heading) =>
  <a href={"#" ++ heading.slug}> {React.string(heading.text)} </a>

let make: Part.component = ({page}) => {
  // Each `##` with the `###` that follow it.
  let groups = page.headings->Array.reduce([], (groups: array<(Part.heading, array<Part.heading>)>, heading) =>
    switch (heading.level, groups->Array.at(-1)) {
    | (2, _) => groups->Array.concat([(heading, [])])
    | (3, Some((top, under))) =>
      groups->Array.slice(~start=0, ~end=-1)->Array.concat([(top, under->Array.concat([heading]))])
    | _ => groups
    }
  )
  groups->Array.length == 0
    ? React.null
    : <ul>
        {groups
        ->Array.map(((top, under)) =>
          <li key=top.slug>
            {link(top)}
            {under->Array.length == 0
              ? React.null
              : <ul> {under->Array.map(one => <li key=one.slug> {link(one)} </li>)->React.array} </ul>}
          </li>
        )
        ->React.array}
      </ul>
}
