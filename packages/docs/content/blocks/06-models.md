---
slug: models
nav: Database models
title: Database models
fixture: model
---
A `::: model` block draws the tables of a database and the relations
between them. Its first lines are a grid, as in `states`: each word is a
table, and a dot leaves a cell empty. After a blank line, a table's name on
its own line starts its description, and each indented line under it is a
column: its name, its type, and a value it may hold, shown as an example.
The type is drawn in `--tone-principle`, as the pane colours it.

An indented line of dashes groups the columns under it, up to the next
one: `--- Classement`. A group gathers properties by facet, or by
ancestor: when its name is a table of the drawing, it holds what the table
inherits from it, and its rows take that table's hue, as a light tint.
Braces work as anywhere: `--- {Accès, color teal}`. A bare `---` is a
group with no name, a plain separation. A thin line crosses the table above
the group, and its name sits at the right of the group's first row, in
light grey. A group
first in the table draws no line, as the table's rule is right above it. A
group with no column under it is refused. A
table the grid holds but nothing describes is drawn with its name alone.
The words after `::: model` are its caption.

A table's name line may end with a tenant after a hash: `Order #eu`. The
tenant is one word. It is shown without the hash at the right of the
table's name, and the table takes the hue its tenant's name hashes to: a
tenant has the same hue in every drawing, whatever the order.

A table in braces holds spaces and its attributes, as a step of `states`
does: `{Order line, #eu, color teal}`, in the grid, on its name line or in
a relation. `color` gives the table a hue of the palette, and wins over
its tenant's.

Every word in braces holds spaces and takes a colour, in a column too. A
column's name and type are each a word, plain or in braces, and the rest
of the line is its value: `description {texte riche}` is a column of type
`texte riche`, and `{id, color red} uuid` marks the column's name in red.
A label takes a colour too: `{orders, color blue}` draws the relation,
its ends and its label in that hue.

`a --o< b label` is a relation. The marks on each side of `--` are its
ends, written as they are drawn, from the table toward the line. A relation
between rows curves. A relation from a table to itself, such as a parent
row, loops at the table's top-right corner. A label sits in the middle of
its relation, unless it says where in braces: `{orders, 0.2}`, or
`{orders, 0.2 right}` on the right of the way. A loop's label stands right of the loop, at its
mid-height.

An end answers two questions, one mark each. A ring says the end may count
no row. A crow's foot says it may count more than one. An end with neither
counts exactly one.

| End | Left of `--` | Right of `--` |
| --- | --- | --- |
| Exactly one | nothing | nothing |
| Zero or one | `o` | `o` |
| One or more | `>` | `<` |
| Zero or more | `>o` | `o<` |

So `Project --o< Site` reads: a site belongs to exactly one project, and a
project has zero or more sites.

`Parent <- Child` is a subclass. It is written as the arrow reads, and
drawn as a class diagram draws it: a line from the child to its parent,
with a hollow triangle at the parent. It takes a label like a relation.

`Definition ..> Workflow` is a process, such as a copy made once. It is
not a link in the data, so it has no ends. It is written as it is drawn:
a dotted line, then a tip at its target. It takes a label like a relation.

The tokens of mermaid's entity relations read too, and draw as the same
four ends: `||` for exactly one, `|o` for zero or one, `}|` for one or more
and `}o` for zero or more, mirrored on the right as `o|`, `|{` and `o{`.
