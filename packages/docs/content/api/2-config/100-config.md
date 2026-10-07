---
name: config
slug: config
kind: file
summary: A YAML file with three keys — base, var, build.
lang: yaml
signature: |-
  base: path/to/base.yaml   # optional
  var:                      # optional
    name: template
  build:                    # optional
    - output: path
      input: template
---

#### Keys

| Key | Type | Meaning |
| --- | --- | --- |
| `base` | path | Another config whose `var` this one inherits. Its own `base` is followed too; a cycle is an error. |
| `var` | map | The config's [vars](#var): templates, groups, and var kinds. |
| `build` | list | The [build entries](#build): what to write. |

#### Behavior

- An entry config is one the `glob` of [`run`](#run) matches. Only entry
  configs write: a base's `build` is not run.
- The context of a config is its base's vars, then its own `var`, merged leaf
  by leaf; its own win.
- Templates from the base render in the inheriting config's context: you
  inherit formulas, not values.
- Paths in a config are relative to its folder, including in templates
  inherited by another config. See [paths](#paths).
- [`dev`](#dev) writes `port` under `var` of an entry config.

#### Example

```yaml
# content/config.yaml
base: ../shared/base.yaml
var:
  site: marmot
  layout:
    file: layout.html
build:
  - output: ../dist/index.html
    input: "{{`layout`}}"
    var:
      title: "{{`site`}}"
```

Guide: [One page](./index.html#one-page), [Formulas, not values](./index.html#formulas-not-values).
