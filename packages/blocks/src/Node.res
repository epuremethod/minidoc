// The middle language: what a block means, between its markdown and its
// HTML. Prose stays markdown inside the nodes; only what a block adds is a
// node.

/** A labelled point of a drawing: the label's position and text. */
type label = {x: float, y: float, text: string}

/** The box a drawing is seen through: its SVG `viewBox`. */
type frame = {left: float, top: float, width: float, height: float}

/** One operation of a `sequence` drawing. */
module SequenceOp = {
  type t =
    | Frame(frame)
    | Head({kind: string, x: float, y: float, width: float, height: float, name: string})
    | Life({x: float, top: float, bottom: float})
    | Message({from: float, to: float, y: float, refused: bool, label: option<label>})
    | State({x: float, y: float, width: float, height: float, text: string})
}

/** One operation of a `states` drawing. */
module StatesOp = {
  type t =
    | Frame(frame)
    | Box({kind: string, x: float, y: float, width: float, height: float, name: string})
    | Move({kind: option<string>, points: array<float>, label: option<(label, string)>})
}

/** One entry of a legend: a kind and its text. A `move` entry is drawn as a line. */
type key = {kind: string, text: string, move: bool}

/** A drawing: its operations, its caption, and its legend when asked for. */
type drawing<'op> = {ops: array<'op>, caption: option<string>, keys: array<key>}

type button = {text: string, primary: bool, clicked: bool}
type choice = {text: string, radio: bool, on: bool}

/** What a screen holds, top to bottom. */
type widget =
  | Text(string)
  | Actions(array<button>)
  | Options(array<choice>)
  | Field(string)

type step = {text: string, details: array<string>}
type column = {title: option<string>, steps: array<step>}

type rec t =
  | Markdown(string)
  | Callout({name: string, label: string, children: array<t>})
  | Quote({author: option<string>, date: option<string>, children: array<t>})
  | Flow({label: string, columns: array<column>})
  | Dialog({owner: option<(string, string)>, title: option<string>, widgets: array<widget>})
  | Screens({caption: option<string>, children: array<t>})
  | Sequence(drawing<SequenceOp.t>)
  | States(drawing<StatesOp.t>)
  | Extra({name: string, info: string, body: string})
