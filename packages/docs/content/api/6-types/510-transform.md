---
name: Transform
slug: transform
kind: type
summary: A function from text to text, named in run and picked by name in a config.
lang: ts
signature: |-
  type Transform = (text: string, page: Page) => string
  type Page = { lang?: string }
  type Transforms = Record<string, Transform>
---

#### Built in

| Name | Does |
| --- | --- |
| `md` | markdown to HTML, with [marked](https://marked.js.org) |
| `none` | nothing: the text as it is |

#### Behavior

- Transforms are given to [`run`](#run) as `transform`, by name. A name
  already built in replaces it everywhere, including files whose transform
  is inferred.
- A `file`, `dir`, `dirs` item or `pages` file picks its transform from its
  extension, unless it names one. A `value` var always names one.
- A transform runs after the references of its text have rendered, and its
  result is never rendered again.
- A transform receives the page it renders. `page.lang` is the `lang` var
  that the page sees: its frontmatter's, else the config's. It is undefined
  when no var sets one. A second parameter with a default value receives
  the page too: read such a value inside the transform.
- Synchronous only.
- Edited transforms take effect in a dev server only with a `build` script.
  See [`watch`](#watch).

#### Example

```js
import { run } from "@minidoc/core"
import { Marked } from "marked"

const md = (text) => new Marked({ gfm: true }).parse(text)
const upper = (text) => text.toUpperCase()

await run({ glob: "content/config.yaml", transform: { md, upper } })
```

Guide: [A reference](./index.html#a-reference).
