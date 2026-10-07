---
slug: api
nav: API calls
title: API calls
fixture: api
---
`::: api GET /path Title` draws an API call: its method, its path, and an
optional title. Its body has parts, each opened by a word at the start of a
line and holding YAML indented under it:

| Part | What it holds |
| --- | --- |
| `query` | the parameters of the URL, also written out after the path |
| `headers` | the headers of the request |
| `body` | what the request sends |
| `response 200 Caption` | a response: its status, then its caption |

A value is drawn rather than printed: an object is a column of keys and
values, a list of plain values is written on one line, a list of objects
holds one card per item, and an empty list says so. A site
translates the words the block shows with
`blocks({ api: { labels: { query, headers, body, response, empty } } })`.
