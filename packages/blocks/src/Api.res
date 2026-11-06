// An API call. `::: api GET /path Title` opens it: a method, a path, and an
// optional title. Its body has parts, each opened by a word at the start of
// a line and holding YAML indented under it:
//
//   query                        the parameters of the URL
//   headers                      the headers of the request
//   body                         what the request sends
//   response 200 Two messages    a response: its status, then its caption
//
// A value is drawn, not printed: an object is a column of keys and values,
// a list of plain values is written on one line, a list of objects holds
// one card per item, and an empty list says so.

@@jsxConfig({version: 4, module_: "Draw"})

open Node

@module("yaml") external parseYaml: string => Nullable.t<JSON.t> = "parse"

let parse: ((string => Nullable.t<JSON.t>), string, string) => JSON.t = %raw(`(parse, text, where) => {
  try { return parse(text) ?? null }
  catch (e) { throw new Error(where + " is not YAML: " + e.message) }
}`)

let partLine = RegExp.fromString("^(query|headers|body|response)(?:\\s+(\\d{3}))?(?:\\s+(\\S.*?))?\\s*$")
let indented = RegExp.fromString("^\\s")

let capture = Sequence.capture

// The lines of a part, moved left by the indent they all share.
let dedent = lines => {
  let indent = line => String.length(line) - String.length(String.trimStart(line))
  let least =
    lines
    ->Array.filter(l => String.trim(l) != "")
    ->Array.reduce(None, (least, l) => Some(Math.Int.min(least->Option.getOr(indent(l)), indent(l))))
    ->Option.getOr(0)
  lines->Array.map(l => String.slice(l, ~start=Math.Int.min(least, indent(l))))->Array.join("\n")
}

let read = (info, body, line) => {
  let (method, rest) = Scan.split(info)
  let (path, title) = Scan.split(rest)
  if method == "" || path == "" {
    Html.fail(`api: an API call names a method and a path, like "GET /messages", line ${Int.toString(line)}`)
  }
  let parts = []
  body
  ->String.split("\n")
  ->Array.forEachWithIndex((text, index) => {
    let at = line + 1 + index
    if String.trim(text) == "" {
      parts->Array.at(-1)->Option.forEach(((_, lines)) => lines->Array.push(text))
    } else if RegExp.test(indented, text) {
      switch parts->Array.at(-1) {
      | Some((_, lines)) => lines->Array.push(text)
      | None => Html.fail(`api: "${String.trim(text)}" belongs to no part, line ${Int.toString(at)}`)
      }
    } else {
      switch RegExp.exec(partLine, text) {
      | Some(m) => parts->Array.push((m, []))
      | None =>
        Html.fail(
          `api: unknown part "${text}", line ${Int.toString(at)}; a part is query, headers, body or response`,
        )
      }
    }
  })
  let parts = parts->Array.map(((m, lines)) => {
    let name = capture(m, 0)->Option.getOr("")
    let status = capture(m, 1)
    {
      name,
      status,
      caption: capture(m, 2),
      value: parse(parseYaml, dedent(lines), `api: the ${name}${status->Option.mapOr("", s => ` ${s}`)}`),
    }
  })
  Api({
    method: String.toUpperCase(method),
    path,
    title: title == "" ? None : Some(title),
    parts,
  })
}

let scalar = (v: JSON.t) =>
  switch v {
  | String(s) => Some(s)
  | Number(n) => Some(Float.toString(n))
  | Boolean(b) => Some(b ? "true" : "false")
  | _ => None
  }

let text = Draw.string
let nl = Draw.string("\n")

let draw = (method, path, title, parts: array<apiPart>, labels: dict<string>) => {
  let label = name => labels->Dict.get(name)->Option.getOr(name)
  let plain = (key, value) => Draw.field(~key, ~value, text(value))
  // A value's key is its part's, then each name or item number on the way to it.
  let rec value = (v: JSON.t, ~at) =>
    switch v {
    | Object(fields) =>
      <dl className="api__fields">
        {fields
        ->Dict.toArray
        ->Array.map(((key, v)) =>
          <div className="api__field">
            <dt> {text(key)} </dt>
            <dd> {value(v, ~at=`${at} ${key}`)} </dd>
          </div>
        )
        ->Draw.array}
      </dl>
    | Array([]) =>
      <p className="api__empty">
        {text(label("empty"))}
        {text(" ")}
        <code> {text("[]")} </code>
      </p>
    | Array(items) if items->Array.every(i => scalar(i)->Option.isSome) =>
      <span className="api__inline">
        {items
        ->Array.mapWithIndex((item, i) => value(item, ~at=`${at} ${Int.toString(i + 1)}`))
        ->Draw.joined(", ")}
      </span>
    | Array(items) =>
      <ol className="api__items">
        {items
        ->Array.mapWithIndex((item, i) =>
          <li className="api__item"> {value(item, ~at=`${at} ${Int.toString(i + 1)}`)} </li>
        )
        ->Draw.array}
      </ol>
    | String(s) => <span className="api__string"> {plain(at, s)} </span>
    | Number(n) => <span className="api__number"> {plain(at, Float.toString(n))} </span>
    | Boolean(b) => <span className="api__literal"> {plain(at, b ? "true" : "false")} </span>
    | Null => <span className="api__literal"> {plain(at, "null")} </span>
    }
  // A query of plain values is also written out after the path.
  let search =
    parts
    ->Array.find(p => p.name == "query")
    ->Option.flatMap(p =>
      switch p.value {
      | Object(fields) =>
        let pairs =
          fields->Dict.toArray->Array.map(((k, v)) => scalar(v)->Option.map(s => `${k}=${s}`))
        pairs->Array.every(Option.isSome) && pairs != []
          ? Some("?" ++ pairs->Array.keepSome->Array.join("&"))
          : None
      | _ => None
      }
    )
  let part = (p: apiPart, index) => <>
    <div className={`api__part api__part--${p.name}`}>
      <p className="api__label">
        {text(label(p.name))}
        {switch p.status {
        | Some(s) =>
          <>
            {text(" ")}
            <span
              className={`api__status api__status--${String.startsWith(s, "2") ? "ok" : "error"}`}
            >
              {text(s)}
            </span>
          </>
        | None => Draw.null
        }}
        {switch p.caption {
        | Some(c) =>
          <>
            {text(" ")}
            <span className="api__caption"> {text(c)} </span>
          </>
        | None => Draw.null
        }}
      </p>
      {p.value == Null ? Draw.null : value(p.value, ~at=`part ${Int.toString(index + 1)}`)}
    </div>
    nl
  </>
  let call = `${method} ${path}${search->Option.getOr("")}`
  <>
    <figure className="api" role="group" ariaLabel={title->Option.getOr(call)}>
      <div className="api__call">
        <span className="api__method"> {plain("method", method)} </span>
        <code className="api__path">
          {plain("path", path)}
          {switch search {
          | Some(s) => <span className="api__search"> {text(s)} </span>
          | None => Draw.null
          }}
        </code>
        {switch title {
        | Some(t) => <span className="api__title"> {plain("title", t)} </span>
        | None => Draw.null
        }}
      </div>
      nl
      {parts->Array.mapWithIndex(part)->Draw.array}
    </figure>
    nl
  </>
}
