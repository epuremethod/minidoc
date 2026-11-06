// minidoc's blocks, live: a block's source read into a value, its drawing as
// React, and a pane that shows its source above a live preview. A host such
// as maia makes its editor's rule from these.

module Blocks = MinidocBlocks.Blocks

/** A block as the person wrote it: its source, and its nodes or why minidoc refuses them. */
type value = {source: string, read: result<array<Blocks.node>, string>}

/** Read a block's source. Any source reads: a refusal is kept in the value, with its reason. */
let read = (source, options: Blocks.options) => {
  source,
  read: try Ok(Blocks.read(source, options)) catch {
  | JsExn(error) => Error(error->JsExn.message->Option.getOr("minidoc could not read this block"))
  | _ => Error("minidoc could not read this block")
  },
}

/** A value's drawing: its nodes as on a static page, or the reason above the source. */
module Drawing = {
  @react.component
  let make = (~value: value, ~options: Blocks.options) => React.useMemo2(() =>
      switch value.read {
      | Ok(nodes) => Tree.make(Blocks.draw(nodes, options))
      | Error(reason) =>
        <div className="refused">
          <p className="refused__reason"> {React.string(reason)} </p>
          <pre className="refused__source"> {React.string(value.source)} </pre>
        </div>
      }
    , (value, options))
}

/**
 * The source in a text field, above the drawing it makes. Each change is
 * handed on. `frame` places the preview, for a host that draws it apart,
 * such as in a shadow root.
 */
module Pane = {
  @react.component
  let make = (
    ~value: value,
    ~options: Blocks.options,
    ~onChange: string => unit,
    ~autoFocus=false,
    ~frame: React.element => React.element=preview => preview,
  ) => {
    let (draft, drafts) = React.useState(() => value.source)
    let shown = React.useMemo2(() => read(draft, options), (draft, options))
    <div className="pane">
      <textarea
        className="pane__source"
        value=draft
        rows={Math.Int.max(draft->String.split("\n")->Array.length, 2)}
        spellCheck=false
        autoFocus
        onChange={event => {
          let next = (event->ReactEvent.Form.target)["value"]
          drafts(_ => next)
          onChange(next)
        }}
      />
      {switch shown.read {
      | Ok(_) => <div className="pane__preview"> {frame(<Drawing value=shown options />)} </div>
      | Error(reason) => <p className="pane__reason"> {React.string(reason)} </p>
      }}
    </div>
  }
}
