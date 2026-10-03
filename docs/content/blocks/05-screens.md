---
slug: screens
nav: Screens
title: Screen mockups
fixture: screens
---
`ui-dialog` draws a screen. Its body is markdown, and some lines become
widgets:

| Line | Widget |
| --- | --- |
| `[Cancel] [[Continue]]` | buttons; double brackets mark the primary one |
| `[Continue]*` | the button the person clicks |
| `( ) No` `(x) Yes` | radio buttons |
| `[ ] No` `[x] Yes` | checkboxes |
| `Password : ____` | an input field |

`ui-flow` holds screens in the order a person sees them. A project names
who presents a screen with `blocks({ "ui-dialog": { owners: { … } } })`,
and each owner's colour is `--tone-<owner>`.
