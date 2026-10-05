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
| `Name : "Sion"` | a field showing a value |
| `Format : "JSON" ▾` | a list to pick from |
| `Token : "a1b2" [Copy]` | buttons beside a field |

`ui-form` draws a wider screen with the same widgets: each label sits
beside its input, and the buttons at its foot keep to the right. Themes set
its width with `--ui-form-width` and its label column with
`--ui-form-label`.

`ui-flow` holds screens in the order a person sees them. A project names
who presents a screen or a form with `blocks({ "ui-dialog": { owners: { … } } })`,
and each owner's colour is `--tone-<owner>`.
