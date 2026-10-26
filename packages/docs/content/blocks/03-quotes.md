---
slug: quotes
nav: Quotes
title: Quotes
fixture: quote
---
A quote names its author in double quotes, and its date after it. Both are
optional.

A quote may also have a name, after a hash at the end of its line:
`::: quote "Code civil, art. 1240" #cc-1240`. The name is its anchor in the
page, and a named quote needs its title in double quotes. Anywhere in the
prose, `` `(cc-1240)` `` is a link to the quote, showing its title. It may
point further down the page.

With `annexe` after its name, the quote moves to the end of the page: only
its title stays in the text, as a link. The page says where the annexe goes
with an empty `::: annexe` block, and the quotes are drawn there whole, in
the order they appear. A callout is named and filed the same way.
