---
slug: sequences
nav: Sequences
title: Sequences
fixture: sequence
---
A `sequence` code block draws what passes between parties, in order. Its
first line names the parties, left to right. Each line after it is a step
down the page: `a -> b label` is a message, `a -x b label` a refusal, and
`a = label` a party's state. `{legend}` adds a legend, and the words after
`sequence` on the fence are its caption.

The nodes are the drawing itself: every box, line and label, placed. A
project names its kinds of party with `blocks({ sequence: { kinds: { … } } })`,
and writes a party as `name:kind`.
