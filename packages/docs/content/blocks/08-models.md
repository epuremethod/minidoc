---
slug: models
nav: Database models
title: Database models
fixture: model
---
A `model` code block draws the tables of a database and the relations
between them. Its first lines are a grid, as in `states`: each word is a
table, and a dot leaves a cell empty. After a blank line, a table's name on
its own line starts its description, and each indented line under it is a
column: its name, its type, and a value it may hold, shown as an example. A
table the grid holds but nothing describes is drawn with its name alone.
The words after `model` on the fence are its caption.

`a --o< b label` is a relation. The marks on each side of `--` are its ends,
written as they are drawn, from the table toward the line. A relation
between rows curves. A label sits in the middle of its relation, unless
`{0.2}` says where, and `{0.2 right}` puts it on the right of the way.

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

The tokens of mermaid's entity relations read too, and draw as the same
four ends: `||` for exactly one, `|o` for zero or one, `}|` for one or more
and `}o` for zero or more, mirrored on the right as `o|`, `|{` and `o{`.
