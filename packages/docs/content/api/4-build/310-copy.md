---
name: copy
slug: copy
kind: build input
summary: Copy a file or a folder to the output, without reading it.
lang: yaml
signature: |-
  - output: path
    input: { copy: path }
---

#### Fields

| Field | Meaning |
| --- | --- |
| `copy` | The file or folder to copy, relative to the config. A template. |

#### Behavior

- A folder is copied recursively.
- The content is never read or rendered: braces in a copied file stay.
- Both paths may hold references; the copied bytes never do.
- Copies into one folder merge, and are exempt from collision checks.
- `copy` cannot be used as the input of [`pages`](#pages).

#### Example

```yaml
build:
  - output: ../dist/styles.css
    input: { copy: styles.css }
  - output: ../dist/fonts
    input: { copy: ../assets/fonts }
```

Guide: [One page](./index.html#one-page).
