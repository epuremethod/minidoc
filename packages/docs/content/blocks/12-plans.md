---
slug: plans
nav: Plans
title: Plans
fixture: plan
---
A plan keeps track of work that runs over several sessions: fix a blocking
bug, then add a block, then show it in another tool. Each step may wait on
another, and the plan says which one is done, which one is under way, and
what is left. Its top numbered items are the stages, drawn as a band. The
bullets under a stage are its todos, listed below the band under their
stage.

A stage starts with its mark: `[x]` is done, `[/]` is in progress, and
`[ ]` is not started. Its bold text is its title. The text after the title
is a message: `2. [/] **Add a plan block** building`. A stage shows its
number and its title on one line, and its message, if it has one, under
them, small and muted. In the band, the rule above each stage shows its
state.
A todo is `[x]` done or `[ ]` open. The title after `::: plan` is
optional. A stage or a todo may have no text yet, as one just added has.

A plan of more than four stages lists them one under the other instead,
in a third of the plan's width, each with its state at the right: a check
when done, a dot in progress, nothing when not started. A click on a stage shows its todos beside
the list, and the page opens on the stage in progress. In a plan narrower
than 30em, the todos open under their stage. In print, every stage shows
its todos.

A plan with no bullets is only the band. A bullet list with no stages is
only the todos. A stage marked done that still has an open todo stops the
build, with the todo's line in the page.

The source stays a task list that reads on GitHub and in an editor. Done
and in progress take their colours from `--tone-done` and `--tone-doing`.
