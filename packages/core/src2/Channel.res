// The page's end of the sync: a socket to `dev`, relative to the page, so
// it works under maia's base. The article saves through it and hears the
// file it shows; the site hears the pages. A closed socket means `dev`
// restarted: the page reloads once it answers again.

type t = {
  send: JSON.t => unit,
  /** Who hears each message: the article, the site. */
  listeners: array<JSON.t => unit>,
  /** What must be done before the page reloads: the article saves its edits. */
  flushers: array<unit => promise<unit>>,
}

let listen = (channel: t, listener) => channel.listeners->Array.push(listener)

/** Run `flusher` before the page reloads. */
let beforeReload = (channel: t, flusher) => channel.flushers->Array.push(flusher)

/** Reload the page once every edit is saved. */
let reload: t => unit = %raw(`(channel) => {
  Promise.all(channel.flushers.map((flush) => flush())).finally(() => location.reload())
}`)

/** The socket of the page that shows `path`, on the version it holds. */
let open_: (~path: string, ~version: int) => t = %raw(`(path, version) => {
  const url = new URL("./__minidoc/sync", location.href)
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:"
  const socket = new WebSocket(url)
  const waiting = []
  const channel = {
    listeners: [],
    flushers: [],
    send: (message) => {
      const text = JSON.stringify(message)
      socket.readyState === 1 ? socket.send(text) : waiting.push(text)
    },
  }
  socket.addEventListener("open", () => {
    socket.send(JSON.stringify({ opens: path, on: version }))
    for (const text of waiting.splice(0)) socket.send(text)
  })
  socket.addEventListener("message", ({ data }) => {
    const message = JSON.parse(data)
    for (const listener of channel.listeners) listener(message)
  })
  socket.addEventListener("close", () => {
    const again = () =>
      fetch(location.href, { cache: "no-store" }).then(
        (res) => (res.ok ? location.reload() : setTimeout(again, 500)),
        () => setTimeout(again, 500),
      )
    setTimeout(again, 300)
  })
  return channel
}`)
