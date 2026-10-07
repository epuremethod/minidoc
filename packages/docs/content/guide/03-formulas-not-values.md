---
title: Formulas, not values
slug: formulas-not-values
desc: Contexts and their layers, base configs, nested vars merged leaf by
  leaf — you inherit templates and they render against your names.
refs: [config, var, reference]
figure: contexts
---

Mara's friend Sam keeps the docs of `marmot-tz`, a plugin. Sam wants the
same layout, the same header, the same footer — and a different site name.

### A base config

Mara moves the shared templates into a file of their own:

```yaml
# shared/base.yaml
var:
  layout:
    file: layout.html
  header: "<header><a href='./'>{{`site`}}</a></header>"
```

Each site's config names it as its `base` and adds what is its own:

```yaml
# marmot-tz/content/config.yaml
base: ../../shared/base.yaml
var:
  site: marmot-tz
build:
  - output: ../dist/index.html
    input: "{{`layout`}}"
    var:
      title: "{{`site`}}"
      main: "{{`header`}}<p>Time zones for marmot.</p>"
```

Sam's header reads *marmot-tz*. The base never knew that name. It declared
``{{`site`}}`` as a reference, and the reference is rendered in Sam's
context, where `site` is `marmot-tz`.

This is the rule from the first chapter, at work: **you inherit formulas,
not values.** Copy a spreadsheet and the formulas come along and recompute
against your own cells. A base config works the same way.

### The layers

A context is built from layers, each merged over the one before:

1. the `base` config, if any;
2. the config's own `var`;
3. the build entry's `var`;
4. the frontmatter of a content file.

The later layer wins. A frontmatter `title` beats the build's, which beats
the config's. Since references render in the nearest context, the base's
``{{`site`}}`` sees whatever the nearest layer says `site` is.

### Nested vars

Templates can be grouped. ``{{`layouts.cv`}}`` reads the `cv` key of the
`layouts` group. Layers merge leaf by leaf, so a later layer can replace one
key and keep the others:

```yaml
# shared/base.yaml
var:
  colors:
    accent: "#0d7797"
    ink: "#111"
```

```yaml
# marmot-tz/content/config.yaml
base: ../../shared/base.yaml
var:
  colors:
    accent: "#a15c24"   # colors.ink is still #111
```

A dotted key is the same leaf written flat: `colors.accent: x` and
`colors: { accent: x }` are one var. Writing it both ways in one layer is an
error.

::: story
Sam changes one color and one name. Everything else comes from Mara's base,
and when Mara fixes a typo in the footer, both sites have the fix on their
next build.
:::

### Under the hood

Each context is a [tilia](https://tiliajs.dev) carve. Every var is a
computed value: lazy, cached, and tracked. A template renders when something
asks for it, once, and files load only when a render needs them. A path can
therefore depend on anything — another var, even another file's
frontmatter — and minidoc reads files in the order the references ask for
them.
