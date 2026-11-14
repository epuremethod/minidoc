// minidoc's blocks, live: a block's source read into a value, its drawing as
// React, and a pane that holds its source. A host such as maia makes its
// editor's rule from these: the pane's changes redraw the drawing in the
// page.

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

/**
 * A value's drawing: its nodes as on a static page. A refused value draws
 * the last value this drawing read well, so a source being typed keeps its
 * drawing; with none yet, it shows the reason above the source.
 */
module Drawing = {
  @react.component
  let make = (~value: value, ~options: Blocks.options) => {
    let good = React.useRef(None)
    switch value.read {
    | Ok(nodes) => good.current = Some(nodes)
    | Error(_) => ()
    }
    let kept = value.read->Result.isError ? good.current : None
    React.useMemo3(() =>
      switch (value.read, kept) {
      | (Ok(nodes), _) | (Error(_), Some(nodes)) => Tree.make(Blocks.draw(nodes, options))
      | (Error(reason), None) =>
        <div className="refused">
          <p className="refused__reason"> {React.string(reason)} </p>
          <pre className="refused__source"> {React.string(value.source)} </pre>
        </div>
      }
    , (value, kept, options))
  }
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
 * may give its own `field`, an editor of one block of text: each text is
 * then drawn in it, all the time.
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
 * A block's source in a text box, with the reason above it when minidoc
 * refuses it. Each change is handed on; the host redraws the drawing from
 * it, in the page.
 */
module Pane = {
  /** Where the caret lands in a source: at the end of its body, before its closing fence. */
  let body = (source: string) => {
    let last = source->String.lastIndexOf("\n")
    let closing = source->String.slice(~start=last + 1)->String.trim
    if last >= 0 && RegExp.test(/^(:{3,}|`{3,}|~{3,})$/, closing) {
      last
    } else {
      source->String.length
    }
  }

  let placing: (Nullable.t<Dom.element>, int) => unit = %raw(`(element, at) => {
    if (element) element.setSelectionRange(at, at)
  }`)

  // The layer scrolls with the text box over it.
  let following: (Nullable.t<Dom.element>, ReactEvent.UI.t) => unit = %raw(`(layer, event) => {
    if (layer) { layer.scrollTop = event.currentTarget.scrollTop; layer.scrollLeft = event.currentTarget.scrollLeft }
  }`)

  /** The source's tokens, each in a span of its kind, and the text between them plain. */
  let colours = (tokens: array<MinidocBlocks.Tokens.token>) =>
    tokens
    ->Array.mapWithIndex(((kind, text), index) =>
      kind == ""
        ? React.string(text)
        : <span key={Int.toString(index)} className={`t-${kind}`}> {React.string(text)} </span>
    )
    ->React.array

  @react.component
  let make = (~value: value, ~options: Blocks.options, ~onChange: string => unit, ~autoFocus=false) => {
    let (draft, drafts) = React.useState(() => value.source)
    let shown = React.useMemo2(() => read(draft, options), (draft, options))
    let tokens = React.useMemo1(() => MinidocBlocks.Tokens.read(draft), [draft])
    let area = React.useRef(Nullable.null)
    let layer = React.useRef(Nullable.null)
    // The pane opens with the caret in the block's body, where the person writes.
    React.useEffect0(() => {
      if autoFocus {
        placing(area.current, body(draft))
      }
      None
    })
    let box =
      <textarea
        className="pane__source"
        ref={ReactDOM.Ref.domRef(area)}
        value=draft
        rows={Math.Int.max(draft->String.split("\n")->Array.length, 2)}
        spellCheck=false
        autoFocus
        onScroll={event => following(layer.current, event)}
        onChange={event => {
          let next = (event->ReactEvent.Form.target)["value"]
          drafts(_ => next)
          onChange(next)
        }}
      />
    <div className="pane">
      {switch shown.read {
      | Ok(_) => React.null
      | Error(reason) => <p className="pane__reason"> {React.string(reason)} </p>
      }}
      // A block with tokens of its own shows its colours under the text box,
      // whose own text is clear. A last line break keeps an empty last line high.
      {switch tokens {
      | Some(tokens) =>
        <div className="pane__field">
          <pre className="pane__source pane__colours" ariaHidden=true ref={ReactDOM.Ref.domRef(layer)}>
            {colours(tokens)}
            {React.string("\n")}
          </pre>
          box
        </div>
      | None => box
      }}
    </div>
  }
}
