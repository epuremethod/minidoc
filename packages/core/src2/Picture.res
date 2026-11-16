// An image on a line of its own: an atom of the editor's format `image`,
// whose value is its markdown line. It draws an `<img>` whose `src` is
// its path from the folder, at the image's version, or the browser's own copy
// of a pasted image until `dev` stores it. Its pane holds the image's text
// and its name: a new name renames the file, and every link to it.

/** An image line: its text, its source, and a title. */
type line = {alt: string, src: string, title: option<string>}

let pattern = /^!\[([^\]\n]*)\]\(([^\s()]*)(?:\s+"([^"\n]*)")?\)\s*$/

let read = (value: string): option<line> =>
  RegExp.exec(pattern, value)->Option.map(found => {
    let part = index => found->RegExp.Result.matches->Array.get(index)->Option.flatMap(x => x)
    {alt: part(0)->Option.getOr(""), src: part(1)->Option.getOr(""), title: part(2)}
  })

let write = ({alt, src, title}: line) =>
  `![${alt}](${src}${title->Option.mapOr("", title => ` "${title}"`)})`

/** The `src` the page draws: the browser's own copy while it uploads, or the file at its version. */
let shown = (site: Site.t, uploads: dict<string>, src: string, ~root="") => {
  // An image of the folder is named from the folder: `root` leads there from the page.
  let from = RegExp.test(/^([a-z][a-z0-9+.-]*:|\/)/i, src) ? "" : root
  switch (uploads->Dict.get(src), site.versions->Dict.get(src)) {
  | (Some(copy), _) => copy
  | (None, Some(version)) => `${from}${src}?v=${Int.toString(version)}`
  | (None, None) => from ++ src
  }
}

/** What the pane needs of the page: the images uploading, and a way to ask for a rename. */
type host = {
  site: Site.t,
  /** The way from the page to the folder. */
  root: string,
  /** The browser's own copy of each image that uploads, by its path. */
  uploads: dict<string>,
  /** Ask `dev` to rename an image: it answers a refusal, or nothing. */
  rename: (string, string) => promise<option<string>>,
}

module Drawn = {
  @react.component
  let make = (~host: host, ~value: string) => {
    TiliaReact.useTilia()
    switch read(value) {
    | Some({alt, src, title}) =>
      <span className="picture">
        <img src={shown(host.site, host.uploads, src, ~root=host.root)} alt ?title />
        {host.uploads->Dict.has(src)
          ? <span className="picture__uploading"> {React.string("Uploading…")} </span>
          : React.null}
      </span>
    | None => <span className="atom__invalid"> {React.string(value)} </span>
    }
  }
}

module Pane = {
  @react.component
  let make = (~host: host, ~value: string, ~onChange: option<string => unit>, ~onLeave: unit => unit) => {
    let line = read(value)->Option.getOr({alt: "", src: "", title: None})
    let (name, setName) = React.useState(() => line.src)
    let (said, say) = React.useState(() => None)
    let readonly = onChange == None
    let rename = () =>
      if name != line.src && !readonly {
        host.rename(line.src, name)
        ->Promise.thenResolve(refused =>
          switch refused {
          | Some(reason) =>
            say(_ => Some(reason))
            setName(_ => line.src)
          | None => say(_ => None)
          }
        )
        ->ignore
      }
    let keys = event =>
      switch ReactEvent.Keyboard.key(event) {
      | "Escape" => onLeave()
      | "Enter" =>
        ReactEvent.Keyboard.preventDefault(event)
        rename()
      | _ => ()
      }
    <div className="picture-pane" onKeyDown=keys>
      <label className="picture-pane__field">
        <span> {React.string("Text")} </span>
        <input
          autoFocus=true
          readOnly=readonly
          placeholder="What the image shows"
          value=line.alt
          onChange={event =>
            onChange->Option.forEach(onChange =>
              onChange(write({...line, alt: ReactEvent.Form.target(event)["value"]}))
            )}
        />
      </label>
      <label className="picture-pane__field">
        <span> {React.string("Name")} </span>
        <input
          readOnly=readonly
          value=name
          onChange={event => setName(ReactEvent.Form.target(event)["value"])}
          onBlur={_ => rename()}
        />
      </label>
      {switch said {
      | Some(reason) => <p className="picture-pane__said"> {React.string(reason)} </p>
      | None => React.null
      }}
    </div>
  }
}

/** The rule of the `image` format. */
let rule = (host: host) =>
  TiliaEditor.Rule.make({
    data: {
      parse: value =>
        switch value {
        | String(text) => Ok(text)
        | _ => Error("An image is its markdown line")
        },
      encode: text => JSON.String(text),
    },
    view: {
      render: ({value}: TiliaEditor.Rule.shown<string>) => <Drawn host value />,
      pane: ({value, onChange, onLeave}: TiliaEditor.Rule.paned<string>) =>
        <Pane host value onChange={onChange->Option.map(onChange => text => onChange({value: text}))} onLeave />,
    },
  })
