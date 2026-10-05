---
slug: callouts
nav: Callouts
title: Callouts
fixture: callouts
---
A callout sets a few lines apart and says what they are. Seven come with
the package: `note`, `draft`, `settled`, `open`, `technical`, `principle`
and `rejected`. Its body is markdown, and it may hold another block when
its colons are more than the inner block's.

A project adds its own with `blocks({ callouts: { risk: "Accepted risk" } })`.
Its colour is the variable `--tone-risk`.
