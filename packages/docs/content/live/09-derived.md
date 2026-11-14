---
slug: derived
nav: Blocks, not braces
title: A block in the flow, not a var in braces
---
Today a page pulls computed content with a var in braces, such as
`scenarios` or `rootDiagram` in radif. `config.yaml` defines the var: a
file, a list or a folder, then a template and a transform. The editor
cannot draw it. It is text in braces until the next build.

The editor already holds atoms in the flow of a page: a drawing, a plan, a
code block. A computed part becomes one more atom, a block that the site
names:

```markdown
::: radif-diagram root-types
:::
```

::: proposed
**A site block is a rule of the editor, and its loader reads the state**
A site block is a format with a rule, made with `Rule.make`, as a
drawing of the blocks package is. Its loader is the setup of a tilia
`source`. The loader reads the files it needs from the carved site, and
tilia tracks those reads.

```rescript
// RootTypes.res: the atom's value is the words after the block's name
let block = Minidoc.block((site, atom) =>
  Diagram.rootTypes(site->Minidoc.text(`../db/${atom.value}.yaml`))
)
```

```js
// RootTypes.mjs
export const block = Minidoc.block((site, atom) =>
  Diagram.rootTypes(Minidoc.text(site, `../db/${atom.value}.yaml`)),
)
```

`Minidoc.block` makes the rule with `Rule.make`. The function it takes is
the rule's loader: it runs inside a tilia `source`.

When `ROOT-TYPES.yaml` changes, the sync puts it in `files`, and tilia
runs the loader again, in each page that shows the block. The editor
draws that atom again, and nothing else. minidoc tracks nothing of its
own. See [The state](#state).

Rejected: a draw function that minidoc calls and whose reads minidoc
records. It is a second way to do what a rule's loader already does.
:::

The page says what it shows, in its own words, where it shows it.
Nothing in `config.yaml` connects a name to a file.
