// markdown-it, set up for the prose between and inside blocks: raw HTML is
// escaped, `h2` and `h3` get an anchor, `` `!text` `` is highlighted, and a
// table is wrapped so that a wide one scrolls.

type t
type env

type token = {
  @as("type") kind: string,
  content: string,
  nesting: int,
  level: int,
}

type config = {html: bool, linkify: bool}

@module("markdown-it") @new external make: config => t = "default"
@send external render: (t, string, env) => string = "render"
@send external renderInline: (t, string, env) => string = "renderInline"
@send external parse: (t, string, env) => array<token> = "parse"

let env = (): env => Obj.magic(Dict.make())

let rawSetup: t => unit = %raw(`(md) => {
  const code = md.renderer.rules.code_inline
  md.renderer.rules.code_inline = (tokens, index, options, env, self) => {
    const content = tokens[index].content
    if (!content.startsWith("!")) return code(tokens, index, options, env, self)
    // The "!" and the one space after it are not shown.
    return '<code class="code--mark">' + md.utils.escapeHtml(content.replace(/^! ?/, "")) + "</code>"
  }
  md.renderer.rules.table_open = () => '<div class="table-wrap"><table>\n'
  md.renderer.rules.table_close = () => "</table></div>\n"
}`)

type anchorOptions = {level: array<int>, slugify: string => string}
type plugin
@module("markdown-it-anchor") external anchor: plugin = "default"
@send external use: (t, plugin, anchorOptions) => t = "use"

let marks = RegExp.fromString("[\\u0300-\\u036f]", ~flags="g")
let others = RegExp.fromString("[^a-z0-9]+", ~flags="g")
let ends = RegExp.fromString("^-|-$", ~flags="g")

let slugify = text =>
  text
  ->String.normalizeByForm(#NFD)
  ->String.replaceRegExp(marks, "")
  ->String.toLowerCase
  ->String.replaceRegExp(others, "-")
  ->String.replaceRegExp(ends, "")

/** A markdown-it instance, with the site's own plugins added by `extend`. */
let make = (extend: option<t => unit>) => {
  let md = make({html: false, linkify: true})
  rawSetup(md)
  md->use(anchor, {level: [2, 3], slugify})->ignore
  extend->Option.forEach(f => f(md))
  md
}
