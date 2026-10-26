---
slug: callouts
nav: Callouts
title: Callouts
fixture: callouts
---
A callout sets a few lines apart and says what they are. Eight come with
the package: `note`, `draft`, `proposed`, `settled`, `open`, `technical`,
`principle` and `rejected`. Its body is markdown, and it may hold another
block when its colons are more than the inner block's. Like a quote, it may
name an author in double quotes and a date after it, shown under its body:
`::: rejected "Ada Lovelace" 1843`. It may also be named, and filed in the
annexe, as a [quote](#quotes) is.

A project adds its own with `blocks({ callouts: { risk: "Accepted risk" } })`.
Its colour is the variable `--tone-risk`.
