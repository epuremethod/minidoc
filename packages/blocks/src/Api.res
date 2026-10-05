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

let render = (method, path, title, parts: array<apiPart>, labels: dict<string>) => {
  let escape = Html.escape
  let label = name => labels->Dict.get(name)->Option.getOr(name)
  let rec value = (v: JSON.t) =>
    switch v {
    | Object(fields) =>
      `<dl class="api__fields">${fields
        ->Dict.toArray
        ->Array.map(((key, v)) => `<div class="api__field"><dt>${escape(key)}</dt><dd>${value(v)}</dd></div>`)
        ->Array.join("")}</dl>`
    | Array([]) => `<p class="api__empty">${escape(label("empty"))} <code>[]</code></p>`
    | Array(items) if items->Array.every(i => scalar(i)->Option.isSome) =>
      `<span class="api__inline">${items->Array.map(value)->Array.join(", ")}</span>`
    | Array(items) =>
      `<ol class="api__items">${items
        ->Array.map(item => `<li class="api__item">${value(item)}</li>`)
        ->Array.join("")}</ol>`
    | String(s) => `<span class="api__string">${escape(s)}</span>`
    | Number(n) => `<span class="api__number">${Float.toString(n)}</span>`
    | Boolean(b) => `<span class="api__literal">${b ? "true" : "false"}</span>`
    | Null => `<span class="api__literal">null</span>`
    }
  // A query of plain values is also written out after the path.
  let search =
    parts
    ->Array.find(p => p.name == "query")
    ->Option.flatMap(p =>
      switch p.value {
      | Object(fields) =>
        let pairs = fields->Dict.toArray->Array.map(((k, v)) => scalar(v)->Option.map(s => `${k}=${s}`))
        pairs->Array.every(Option.isSome) && pairs != []
          ? Some("?" ++ pairs->Array.keepSome->Array.join("&"))
          : None
      | _ => None
      }
    )
  let part = (p: apiPart) => {
    let status = p.status->Option.mapOr("", s =>
      ` <span class="api__status api__status--${String.startsWith(s, "2") ? "ok" : "error"}">${escape(s)}</span>`
    )
    let caption = p.caption->Option.mapOr("", c => ` <span class="api__caption">${escape(c)}</span>`)
    let inner = p.value == Null ? "" : value(p.value)
    `<div class="api__part api__part--${p.name}"><p class="api__label">${escape(label(p.name))}${status}${caption}</p>${inner}</div>\n`
  }
  let call = `${escape(method)} ${path}${search->Option.getOr("")}`
  `<figure class="api" role="group" aria-label="${escape(title->Option.getOr(call))}"><div class="api__call"><span class="api__method">${escape(
      method,
    )}</span><code class="api__path">${escape(path)}${search->Option.mapOr("", s =>
      `<span class="api__search">${escape(s)}</span>`
    )}</code>${title->Option.mapOr("", t => `<span class="api__title">${escape(t)}</span>`)}</div>\n${parts
    ->Array.map(part)
    ->Array.join("")}</figure>\n`
}
