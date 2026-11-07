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
    | Move({kind: option<string>, both: bool, points: array<float>, label: option<(label, string)>})
}

/** One operation of a `model` drawing. */
module ModelOp = {
  /**
   * How many rows an end of a relation stands for. A ring says it may be
   * none, a crow's foot that it may be more than one, and a plain end
   * exactly one.
   */
  type arity =
    | One
    | Optional
    | More
    | Any

  /** A column of a table: its baseline, its name, its type, and a value it may hold. */
  type column = {y: float, name: string, kind: option<string>, value: option<string>}

  type t =
    | Frame(frame)
    | Table({
        x: float,
        y: float,
        width: float,
        height: float,
        name: string,
        tenant: option<string>,
        kindX: float,
        valueX: float,
        columns: array<column>,
      })
    | Link({from: arity, to: arity, points: array<float>, label: option<(label, string)>})
    /** A subclass line, drawn from the child to its parent. */
    | Parent({points: array<float>, label: option<(label, string)>})
}

/** One entry of a legend: a kind and its text. A `move` entry is drawn as a line. */
type key = {kind: string, text: string, move: bool}

/** A drawing: its operations, its caption, and its legend when asked for. */
type drawing<'op> = {ops: array<'op>, caption: option<string>, keys: array<key>}

type button = {text: string, primary: bool, clicked: bool}
type choice = {text: string, radio: bool, on: bool}
/** An input: empty, or showing a value, or a list to pick from, with buttons beside it. */
type field = {label: string, value: option<string>, select: bool, buttons: array<button>}

/** What a screen holds, top to bottom. */
type widget =
  | Text(string)
  | Actions(array<button>)
  | Options(array<choice>)
  | Field(field)

type step = {text: string, details: array<string>}
/** A part of an API call: its name, a response's status and caption, and its value. */
type apiPart = {name: string, status: option<string>, caption: option<string>, value: JSON.t}
type column = {title: option<string>, steps: array<step>}

/** Where a stage of a plan stands. */
type stageState =
  | Done
  | Doing
  | NotStarted

/** A todo of a plan, and the line it starts on in the page, from 1. */
type todo = {text: string, done: bool, line: int}
/** A stage of a plan: its state, its title, the message beside its number, its todos, and its line. */
type stage = {
  state: stageState,
  title: string,
  message: option<string>,
  todos: array<todo>,
  line: int,
}

type rec t =
  | Markdown(string)
  | Callout({
      name: string,
      label: string,
      author: option<string>,
      date: option<string>,
      url: option<string>,
      anchor: option<string>,
      annexe: bool,
      children: array<t>,
    })
  | Quote({
      author: option<string>,
      date: option<string>,
      /** The official source its title links to, after the date in `<` and `>`. */
      url: option<string>,
      /** The block's name after `#`, its id in the page. */
      anchor: option<string>,
      /** Drawn in the annexe, leaving a link to its title in its place. */
      annexe: bool,
      children: array<t>,
    })
  /** Where the blocks filed in the annexe are drawn. */
  | Annexe
  | Flow({label: string, columns: array<column>})
  /** A plan holds stages, or todos only. */
  | Plan({title: option<string>, stages: array<stage>, todos: array<todo>, line: int})
  | Dialog({owner: option<(string, string)>, title: option<string>, widgets: array<widget>})
  | Form({owner: option<(string, string)>, title: option<string>, widgets: array<widget>})
  | Screens({caption: option<string>, children: array<t>})
  | Api({method: string, path: string, title: option<string>, parts: array<apiPart>})
  | Sequence(drawing<SequenceOp.t>)
  | States(drawing<StatesOp.t>)
  | Model(drawing<ModelOp.t>)
  | Extra({name: string, info: string, body: string})
