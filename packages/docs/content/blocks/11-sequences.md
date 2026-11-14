---
slug: sequences
nav: Sequences
title: Sequences
fixture: sequence
---
A `::: sequence` block draws what passes between parties, in order. Its
first line names the parties, left to right. Each line after it is a step
down the page: `a -> b label` is a message, `a -x b label` a refusal, and
`a = label` a party's state. `{legend}` adds a legend, and the words after
`::: sequence` are its caption.

The nodes are the drawing itself: every box, line and label, placed. A
project names its kinds of party with `blocks({ sequence: { kinds: { … } } })`,
and writes a party as `name:kind`. A party in braces holds spaces and its
attributes, as a step of `states` does: `{web browser, color blue}`.

Every word in braces takes a colour, a label too: `a -> b {paid, color
green}` draws the message, its tip and its label in that hue, and `a =
{waiting, color orange}` the state. A colour has no legend: when the hue
means something, a kind says it better.
