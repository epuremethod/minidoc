// A file that lands in the page, on the page's side. The file is read as
// the editor reads it, and each block that was in the last section keeps
// its id, so the merge works block by block, and a block nobody changed
// still writes back with its own bytes.

/** The page's markdown, read as the editor reads it. */
let read = (text: string, ~kinds: array<string>, ~blocks: dict<string>) =>
  Editor.Page.read(text, ~kinds, ~blocks)

/**
 `text` read against `base`, the last section the page and the server
 agreed on: a block or an atom that was there keeps its id, a new one takes
 `mint()`.
*/
let against = (
  text: string,
  ~base: Editor.Section.t,
  ~mint: unit => string,
  ~kinds: array<string>,
  ~blocks: dict<string>,
): Editor.Page.t => Editor.Page.read(text, ~kinds, ~blocks, ~base, ~mint)

/**
 The merge of a file that landed, as the radif binding merges a row: a
 block, an atom or a use changed in the page since `base` keeps the page's
 one, and the next save carries it. Anything else takes the file's. One
 made in the page and not yet saved stays after the one it follows.
*/
let merge = (~base: Editor.Section.t, ~local: Editor.Section.t, ~remote: Editor.Section.t): Editor.Section.t => {
  let keep = (base, local, remote, ~key) => {
    let find = (entries, id) => entries->Array.find(entry => key(entry) == id)
    let merged = remote->Array.map(entry =>
      switch (find(base, key(entry)), find(local, key(entry))) {
      | (Some(was), Some(here)) if was != here => here
      | _ => entry
      }
    )
    local->Array.forEachWithIndex((entry, index) =>
      if find(base, key(entry)) == None && find(remote, key(entry)) == None {
        let before =
          local
          ->Array.slice(~start=0, ~end=index)
          ->Array.findLast(previous => find(merged, key(previous)) != None)
        let at = switch before {
        | Some(previous) => merged->Array.findIndex(other => key(other) == key(previous)) + 1
        | None => 0
        }
        merged->Array.splice(~start=at, ~remove=0, ~insert=[entry])
      }
    )
    merged
  }
  {
    id: remote.id,
    blocks: keep(base.blocks, local.blocks, remote.blocks, ~key=((id, _)) => id),
    atoms: keep(base.atoms, local.atoms, remote.atoms, ~key=(atom: Editor.Section.atom) => atom.id),
    uses: keep(base.uses, local.uses, remote.uses, ~key=((key, _)) => key),
  }
}
