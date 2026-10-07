# Session

Step 1 of the session fills **Intention**, step 3 fills **Technical**. When
the session closes, any choice worth remembering is appended to
`DECISIONS.md` and this file is cleared back to exactly what you are
reading. See `CONTRIBUTING.md`.

## Intention

A page served by `dev` can hang when the author moves between pages.

Each page that `dev` serves opens a reload stream to `/__minidoc` and never
closes it. A browser keeps at most six connections open to one host. With
several tabs, or with pages kept in the back and forward cache, the streams
take all six. The next page then waits for a free connection, and looks
frozen.

The change: the page closes its reload stream when it is hidden, and opens
it again when it is shown. A page that comes back from the cache still
reloads after a build.

It serves the author who runs `dev` and keeps several pages or tabs open.
The built site does not change: it has no reload stream.

The scenario, in `test/dev.test.mjs`: run the script injected into a served
page against a stand-in window and `EventSource`. Hiding the page closes the
stream. Showing it opens a new one. A message on the new stream reloads the
page.

## Technical
