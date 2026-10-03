// The line scanner: a document split into markdown runs and blocks. It is
// also the strict check, so it knows each line's number in the page.

type item =
  | Run(string)
  | Block({name: string, info: string, body: string, line: int})

/** The names that open a block: after colons, or as a code fence's info word. */
type names = {containers: array<string>, fences: array<string>}

let fail = Html.fail

let codeLine = RegExp.fromString("^\\s{0,3}(`{3,}|~{3,})(.*)$")
let colonLine = RegExp.fromString("^\\s*(:{3,})\\s*(.*?)\\s*$")
let space = RegExp.fromString("\\s+")

let capture = (m, index) => m->RegExp.Result.matches->Array.get(index)->Option.flatMap(x => x)->Option.getOr("")

/** The first word of `text`, and the rest after it. */
let split = text => {
  let text = String.trim(text)
  switch String.search(text, space) {
  | -1 => (text, "")
  | at => (String.slice(text, ~start=0, ~end=at), String.trim(String.slice(text, ~start=at)))
  }
}

// The line that closes the code fence opened at `start`, or the end.
let fenceEnd = (lines, start, marker) => {
  let char = String.charAt(marker, 0)
  let rec go = index =>
    switch lines->Array.get(index) {
    | None => index
    | Some(line) =>
      switch RegExp.exec(codeLine, line) {
      | Some(m)
        if String.charAt(capture(m, 0), 0) == char &&
        String.length(capture(m, 0)) >= String.length(marker) &&
        String.trim(capture(m, 1)) == "" => index
      | _ => go(index + 1)
      }
    }
  go(start + 1)
}

// The line that closes the block opened at `start`. Code fences inside are
// skipped, and nested blocks are counted, so their closes are not ours.
let blockEnd = (lines, start, marker, offset) => {
  let depth = [String.length(marker)]
  let rec go = index =>
    switch lines->Array.get(index) {
    | None => fail(`Unclosed block on line ${Int.toString(offset + start)}`)
    | Some(line) =>
      switch RegExp.exec(codeLine, line) {
      | Some(m) => go(fenceEnd(lines, index, capture(m, 0)) + 1)
      | None =>
        switch RegExp.exec(colonLine, line) {
        | None => go(index + 1)
        | Some(m) if capture(m, 1) != "" =>
          depth->Array.push(String.length(capture(m, 0)))
          go(index + 1)
        | Some(m) =>
          let opened = depth->Array.pop->Option.getOr(0)
          if String.length(capture(m, 0)) < opened {
            fail(`Mismatched block close on line ${Int.toString(offset + index)}`)
          }
          depth->Array.length == 0 ? index : go(index + 1)
        }
      }
    }
  go(start + 1)
}

let blank = line => String.trim(line) == ""

/** The lines of a run, without the blank lines around them. */
let trimmed = lines => {
  let first = lines->Array.findIndex(line => !blank(line))
  let last = lines->Array.findLastIndex(line => !blank(line))
  first < 0 ? None : Some(lines->Array.slice(~start=first, ~end=last + 1)->Array.join("\n"))
}

/** Split `text`, whose first line is line `offset` of the page. */
let scan = (text, offset, names) => {
  let lines = String.split(text, "\n")
  let items = []
  let run = []
  let flush = () => {
    trimmed(run)->Option.forEach(text => items->Array.push(Run(text)))
    run->Array.splice(~start=0, ~remove=Array.length(run), ~insert=[])
  }
  let slice = (start, end) => lines->Array.slice(~start, ~end)->Array.join("\n")
  let rec go = index =>
    switch lines->Array.get(index) {
    | None => flush()
    | Some(line) =>
      switch RegExp.exec(codeLine, line) {
      | Some(m) =>
        let end = fenceEnd(lines, index, capture(m, 0))
        let (word, info) = split(capture(m, 1))
        if names.fences->Array.includes(word) {
          flush()
          items->Array.push(
            Block({name: word, info, body: slice(index + 1, end), line: offset + index}),
          )
        } else {
          lines->Array.slice(~start=index, ~end=end + 1)->Array.forEach(l => run->Array.push(l))
        }
        go(end + 1)
      | None =>
        switch RegExp.exec(colonLine, line) {
        | None =>
          run->Array.push(line)
          go(index + 1)
        | Some(m) if capture(m, 1) == "" =>
          fail(`Mismatched block close on line ${Int.toString(offset + index)}`)
        | Some(m) =>
          let (name, info) = split(capture(m, 1))
          if !(names.containers->Array.includes(name)) {
            fail(`Unknown block on line ${Int.toString(offset + index)}: ${name}`)
          }
          let end = blockEnd(lines, index, capture(m, 0), offset)
          flush()
          items->Array.push(Block({name, info, body: slice(index + 1, end), line: offset + index}))
          go(end + 1)
        }
      }
    }
  go(0)
  items
}
