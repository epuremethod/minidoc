---
slug: callouts
nav: Callouts
title: Callouts
fixture: callouts
---
A callout sets a few lines apart and says what they are. Nine come with
the package: `note`, `draft`, `proposed`, `settled`, `open`, `technical`,
`principle`, `rejected` and `comment`. Its body is markdown, and it may hold another
block when its colons are more than the inner block's. Like a quote, it may
name an author in double quotes and a date after it, shown under its body:
`::: rejected "Ada Lovelace" 1843`. It may also be named, and filed in the
annexe, as a [quote](#quotes) is.

A `comment` carries a remark or a proposed change, often left by an
agent, with its author and its date: `::: comment "Claude" 2026-11-12`. It
goes once resolved. A page that edits itself, in minidoc's `dev` edit mode,
shows a × in its head: a click removes the whole block from the markdown.
A static page shows no ×. A comment has no label: a speech bubble, its
author and its date head it on one line. It halts the article: it is as
wide as the text, shifted `--comment-shift` to the right on a screen at
least 60rem wide, and the text goes on under it. It never floats and never
folds, so it is not forgotten.

A project adds its own with `blocks({ callouts: { risk: "Accepted risk" } })`.
Its colour is the variable `--tone-risk`.

A label in another lang is written with the lang as a prefix:
`callouts: { "fr.settled": "Décidé" }`. A page whose `lang` var is `fr`
shows "Décidé", and the kind stays `::: settled`. A kind with no label in
the page's lang keeps its own.
