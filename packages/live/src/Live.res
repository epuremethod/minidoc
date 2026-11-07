// minidoc's blocks, live: a block's source read into a value, its drawing as
// React, and a pane that shows its source above a live preview. A host such
// as maia makes its editor's rule from these.

module Blocks = MinidocBlocks.Blocks
module Draw = MinidocBlocks.Draw

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

/** The props of a host's text field, and its handle. See `Tree.textField`. */
type textField = Tree.textField
type handle = Tree.handle
type place = Tree.place
type cut = Tree.cut

/**
 * A block the person edits where it stands: a plan, in this version. Its
 * texts show their drawing, and their source under the caret; a click
 * ticks a todo or moves a stage along. Each change hands on the block's
 * new source. A source handed in that this editor did not hand out
 * replaces what it shows. Any other block draws as `Drawing` does. A host
 * may give its own `field`, a one-line editor: each text is then drawn in
 * it, all the time.
 */
module Editor = {
  @react.component
  let make = (
    ~value: value,
    ~options: Blocks.options,
    ~onChange: string => unit,
    ~field: option<React.component<textField>>=?,
  ) => {
    let scope = React.useId()
    let handles: React.ref<dict<handle>> = React.useRef(Dict.make())
    let named = ((key, n)) => `${Int.toString(n)} ${key}`
    // The field an act moved the caret to, which takes the focus once drawn.
    let pending = React.useRef(None)
    let focuses = (key, n, at) =>
      handles.current->Dict.get(named((key, n)))->Option.forEach(handle => handle.focus(at))
    React.useEffectOnEveryRender(() => {
      switch pending.current {
      | Some((key, n, at)) =>
        pending.current = None
        focuses(key, n, at)
      | None => ()
      }
      None
    })
    let (source, sources) = React.useState(() => value.source)
    let handed = React.useRef([value.source])
    React.useEffect1(() => {
      if !(handed.current->Array.includes(value.source)) {
        handed.current = [value.source]
        sources(_ => value.source)
      }
      None
    }, [value.source])
    let (caret, carets) = React.useState(() => None)
    let (at, ats) = React.useState((): place => End)
    let (draft, drafts) = React.useState(() => "")
    let shown = React.useMemo2(() => read(source, options), (source, options))
    switch shown.read {
    | Ok(nodes) if Blocks.editable(nodes) =>
      let valueOf = (source, key) =>
        switch read(source, options).read {
        | Ok(nodes) =>
          Draw.fields(Blocks.draw(nodes, options))
          ->Array.find(((k, _)) => k == key)
          ->Option.mapOr("", ((_, v)) => v)
        | Error(_) => ""
        }
      let acts = (act: Draw.act) =>
        switch Blocks.edit(source, act, options) {
        | edited =>
          handed.current = handed.current->Array.concat([edited.source])->Array.slice(~start=-50)
          sources(_ => edited.source)
          onChange(edited.source)
          switch (act, edited.caret) {
          | (Write(_), _) | (_, None) => ()
          | (_, Some(key)) =>
            // A todo split hands the caret to the start of its second half.
            let place: place = switch act {
            | SplitTodo(_) => Start
            | _ => End
            }
            pending.current = Some((key, 0, place))
            ats(_ => place)
            carets(_ => Some((key, 0)))
            drafts(_ => valueOf(edited.source, key))
          }
        // An act that cannot apply, such as removing a plan's last todo, does nothing.
        | exception _ => ()
        }
      Tree.make(
        ~scope,
        ~editing={
          caret,
          at,
          draft,
          enters: (key, n, value) => {
            ats(_ => End)
            carets(_ => Some((key, n)))
            drafts(_ => value)
          },
          writes: (key, text) => {
            drafts(_ => text)
            acts(Write({key, text}))
          },
          leaves: (key, n) => carets(now => now == Some((key, n)) ? None : now),
          acts,
          field,
          handles: (field, handle) =>
            switch handle->Nullable.toOption {
            | Some(handle) => handles.current->Dict.set(named(field), handle)
            | None => handles.current->Dict.delete(named(field))
            },
          focuses: (key, n) => focuses(key, n, End),
        },
        Blocks.draw(nodes, options),
      )
    | _ => <Drawing value=shown options />
    }
  }
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
