---
slug: states
nav: State machines
title: State machines
fixture: states
---
A `::: states` block draws steps and the moves between them. Its first
lines are a grid: each word is a box, and a dot leaves a cell empty. After
a blank line, `a -> b label` is a move, and `a <-> b label` a move both
ways, with a tip at each end. A move between rows curves. A label
sits in the middle of its move, unless it says where in braces:
`{submit, 0.2}` puts it a fifth of the way, and `{submit, 0.2 right}` on
the right of the way.

A state machine reads left to right. A move to a later column on another
row leaves its box's right side, so a step can fork: the moves out of one
right side start from one point and part after it.

A name in braces holds spaces, and its attributes follow it after commas:
`{en attente, active}`, in the grid or in a move. `active` marks a step in
progress, in the tone of a plan's current stage. `color red` gives a step a
hue of the theme's palette: grey, red, orange, yellow, green, teal, blue
or purple. Any other word, such as `color important`, is hashed into the
palette, so it gives the same hue on every page. One mention of a name
is enough; two that give it two colours are refused.

A label in braces takes a colour too: `{rework, 0.4, color red}` draws
the move, its tip and its label in that hue. A colour comes before a
kind's tone, as on a box. A colour has no legend: when the hue means
something, a kind says it better.
