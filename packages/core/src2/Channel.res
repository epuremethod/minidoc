// The page's end of the sync: a socket to `dev`, relative to the page, so
// it works under maia's base. The article saves through it and hears the
// file it shows; the site hears the pages.

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

/**
 The socket of the page that shows `path`, on the version it holds. A
 socket that was open and closes means `dev` restarted: the page reloads
 once the server answers. A socket that never opens, as behind a proxy
 that does not pass it, or a page that reloaded 3 times in 10 s, does not
 reload: the page says the sync is off and tries again, later each time.
*/
let open_: (~path: string, ~version: int) => t = %raw(`(path, version) => {
  const url = new URL("./__minidoc/sync", location.href)
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:"
  const waiting = []
  let socket
  const channel = {
    listeners: [],
    flushers: [],
    send: (message) => {
      const text = JSON.stringify(message)
      socket?.readyState === 1 ? socket.send(text) : waiting.push(text)
    },
  }
  let banner
  const off = (shown) => {
    if (!shown) return banner?.remove()
    if (banner?.isConnected) return
    banner = document.createElement("div")
    banner.setAttribute("role", "status")
    banner.setAttribute("data-minidoc", "sync-off")
    banner.textContent = "The sync is off. Edits are not saved. minidoc tries again."
    banner.style.cssText =
      "position:fixed;left:50%;bottom:1rem;transform:translateX(-50%);z-index:10;padding:.5rem 1rem;" +
      "border-radius:6px;background:CanvasText;color:Canvas;font:14px/1.4 system-ui,sans-serif"
    document.body.append(banner)
  }
  // The times of this tab's last reloads, which stay across them.
  const reloads = () => {
    try {
      return JSON.parse(sessionStorage.getItem("minidoc-reloads") || "[]").filter((at) => Date.now() - at < 10000)
    } catch {
      return []
    }
  }
  const reload = () => {
    try {
      sessionStorage.setItem("minidoc-reloads", JSON.stringify([...reloads(), Date.now()]))
    } catch {}
    location.reload()
  }
  let delay = 500
  const connect = () => {
    let opened = false
    socket = new WebSocket(url)
    socket.addEventListener("open", () => {
      opened = true
      delay = 500
      off(false)
      socket.send(JSON.stringify({ opens: path, on: version }))
      for (const text of waiting.splice(0)) socket.send(text)
    })
    socket.addEventListener("message", ({ data }) => {
      const message = JSON.parse(data)
      for (const listener of channel.listeners) listener(message)
    })
    socket.addEventListener("close", () => {
      if (!opened || reloads().length >= 3) {
        off(true)
        setTimeout(connect, delay)
        delay = Math.min(delay * 2, 30000)
        return
      }
      const again = () =>
        fetch(location.href, { cache: "no-store" }).then(
          (res) => (res.ok ? reload() : setTimeout(again, 500)),
          () => setTimeout(again, 500),
        )
      setTimeout(again, 300)
    })
  }
  connect()
  return channel
}`)
