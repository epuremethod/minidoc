---
slug: sync
nav: The local sync
title: The local sync
---
Nothing rebuilds and nothing reloads. A change is a section that lands,
from either side.

::: sequence A change on disk
disk dev page
disk -> dev  foo.yaml changed
dev = maps it
dev -> page  the new section
page = merges
:::

The watcher sees the file change. `dev` maps the file to its section and
sends the section to each page that shows it. Each page merges it with
the text its person typed since the last save, through the editor's
three-way merge. tilia then redraws only the atoms and blocks that
changed. The caret, the open panel and the scroll stay.

::: sequence A key in the page
person page dev disk
person -> page  types
page -> dev  the section, on version 4
dev -> disk  the file
dev -> page  version 5
:::

The page saves as the editor saves: when the person pauses, or at once for
a split, a join or a move. `dev` maps the section to the file, writes it,
and sends the new version to the other pages.

Each file has a version. A save names the version it starts from. When
the file changed in the meantime, `dev` refuses the save and sends the
section that stands. The page merges it and saves again, on the new
version. So a save never writes over a change that the page did not see.

::: sequence Two changes at once
page dev disk
disk -> dev  a.md changed
page -> dev  a.md, on version 4
dev -x page  version 5 stands
dev -> page  version 5
page = merges
page -> dev  a.md, on version 5
:::

A failed save keeps the person's edits in the page, as today, until a
save succeeds.
