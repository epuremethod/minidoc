// The development runner — watch, rebuild, serve.
//
// Node-only by nature, and lazily so: every builtin loads through a dynamic
// import, exactly like `nodeFs`, so importing minidoc in a browser stays safe.
//
// A rebuild runs the build script in a *fresh* process. That is what makes an
// edited transformer take effect: transforms reach `run` as closures, and no
// ESM cache ever hands back a module a file has changed under.

open Schema

external magic: 'a => 'b = "%identity"

let import_: string => promise<'a> = %raw(`(name) => import(name)`)

@scope("process") @val external cwd: unit => string = "cwd"
@scope("process") @val external execPath: string = "execPath"

type timer
@val external later: (unit => unit, int) => timer = "setTimeout"
@val external cancel: timer => unit = "clearTimeout"

let say = message => Console.log(`minidoc: ${message}`)

let absolute = (base, path) => String.startsWith(path, "/") ? path : join(base, path)

let slashes = RegExp.fromString("\\\\", ~flags="g")

// ---------------------------------------------------------------------------
// What counts as a change.

/** Directories a site is never built from — output, dependencies, artefacts. */
let ignored = ["dist", "node_modules", "lib"]

/** Content, config, and the modules a transformer lives in. */
let extensions = [
  "md",
  "markdown",
  "yml",
  "yaml",
  "html",
  "htm",
  "css",
  "svg",
  "js",
  "mjs",
  "cjs",
  "ts",
  "mts",
]

// An editor saving one file writes several — `.#page.md`, `page.md~`, a bare
// `4913` — and a build writes its own output. A change that is none of ours is
// not a change; dot-names go unwatched, which also covers `.git`.
let changed = (skip, exts, name) => {
  let parts = String.replaceRegExp(name, slashes, "/")->String.split("/")
  let base = parts->Array.at(-1)->Option.getOr("")
  !(parts->Array.some(p => p == "" || String.startsWith(p, ".") || skip->Array.includes(p))) &&
  !String.endsWith(base, "~") &&
  switch String.lastIndexOf(base, ".") {
  | -1 => false
  | at => exts->Array.includes(String.slice(base, ~start=at + 1))
  }
}

// ---------------------------------------------------------------------------
// Building.

type failure = {message: string, stack: string}

let attempt: (unit => promise<unit>) => promise<Nullable.t<failure>> = %raw(`async (fn) => {
  try { await fn(); return null } catch (e) {
    return {message: String((e && e.message) || e), stack: e && typeof e.stack === "string" ? e.stack : String(e)}
  }
}`)

/** Fail with a message the terminal has already seen: no stack to print. */
let quiet: string => 'a = %raw(`(message) => { const e = new Error(message); e.stack = ""; throw e }`)

// One build at a time, and never a stale one: changes arriving mid-build
// queue exactly one more run, however many of them there are. `built` fires
// once the burst has settled, with the message of the last run's failure,
// if any. The terminal gets the stack; the message is for the page.
let looper = (rebuild, built) => {
  let busy = ref(false)
  let again = ref(false)
  let rec go = async () => {
    busy := true
    let started = Date.now()
    let failure = (await attempt(rebuild))->Nullable.toOption
    busy := false
    switch failure {
    | Some({stack: ""}) => ()
    | Some(f) => Console.error(f.stack)
    | None => say(`built in ${(Date.now() -. started)->Float.toInt->Int.toString}ms`)
    }
    if again.contents {
      again := false
      await go()
    } else {
      built(failure->Option.map(f => f.message))
    }
  }
  async () =>
    if busy.contents {
      again := true
    } else {
      await go()
    }
}

type spawner
type cpmod = {spawn: spawner}

// The script's stderr goes through to the terminal and is kept: what it
// printed is the failure, and the page that stays up will show it.
let rawSpawn: (spawner, string, array<string>, string) => promise<(int, string)> = %raw(`(spawn, bin, args, cwd) =>
  new Promise((resolve) => {
    const child = spawn(bin, args, {cwd, stdio: ["inherit", "inherit", "pipe"]})
    let said = ""
    child.stderr.on("data", (chunk) => { process.stderr.write(chunk); said += chunk })
    child.on("exit", (code) => resolve([code ?? 1, said]))
    child.on("error", (e) => { console.error(e); resolve([1, said + String(e)]) })
  })`)

/** Run a build script in a fresh process, so its transformers are fresh too. */
let script = async (path, at) => {
  let cp: cpmod = await import_("node:child_process")
  let (code, said) = await rawSpawn(cp.spawn, execPath, [path], at)
  if code != 0 {
    let exit = `build script ${path} exited with code ${Int.toString(code)}`
    Console.error(exit)
    let said = String.trim(said)
    quiet(said == "" ? exit : `${said}\n${exit}`)
  }
}

// ---------------------------------------------------------------------------
// The node filesystem — what the watcher listens to and the server reads.

type bytes
@send external text: (bytes, string) => string = "toString"

type stats
@send external isFile: stats => bool = "isFile"
@send external isFolder: stats => bool = "isDirectory"
type promises = {readFile: string => promise<bytes>, stat: string => promise<stats>}

type wopts = {recursive: bool, persistent: bool}
type watcher
type nodefs = {watch: (string, wopts, (string, Nullable.t<string>) => unit) => watcher}
@send external unwatch: watcher => unit = "close"

// ---------------------------------------------------------------------------
// Watching.

let folder = async path =>
  try {
    let fs: promises = await import_("node:fs/promises")
    isFolder(await fs.stat(path))
  } catch {
  | _ => false
  }

// One watcher per path: the root, and whatever else a site is built from —
// a folder is watched all the way down, a single file as itself.
let watching = async (paths, skip, exts, trigger) => {
  let fs: nodefs = await import_("node:fs")
  let pending: ref<option<timer>> = ref(None)
  // One save is several events; the last one wins.
  let soon = () => {
    pending.contents->Option.forEach(cancel)
    pending :=
      Some(
        later(() => {
          pending := None
          trigger()->ignore
        }, 60),
      )
  }
  await Promise.all(
    paths->Array.map(async path => {
      let deep = await folder(path)
      fs.watch(path, {recursive: deep, persistent: true}, (_event, name) =>
        switch name->Nullable.toOption {
        | Some(name) => changed(skip, exts, name) ? soon() : ()
        // A watched file reporting no name is the file itself.
        | None => deep ? () : soon()
        }
      )
    }),
  )
}

// ---------------------------------------------------------------------------
// Serving.

type req
type res
type server
type httpmod = {createServer: ((req, res) => unit) => server}

@get external target: req => string = "url"
@send external head: (res, int, dict<string>) => unit = "writeHead"
@send external finish: (res, 'a) => unit = "end"
@send external push: (res, string) => bool = "write"
@send external onClose: (res, string, unit => unit) => unit = "on"
@send external shut: server => unit = "close"
@send external drop: server => unit = "closeAllConnections"
@val external decode: string => string = "decodeURIComponent"
@scope("JSON") @val external stringify: string => string = "stringify"

/** The file at `path`, or nothing when it is missing or is not a file. */
let readBytes = async path => {
  let fs: promises = await import_("node:fs/promises")
  try {
    let info = await fs.stat(path)
    isFile(info) ? Some(await fs.readFile(path)) : None
  } catch {
  | _ => None
  }
}

let types = Dict.fromArray([
  ("html", "text/html; charset=utf-8"),
  ("htm", "text/html; charset=utf-8"),
  ("css", "text/css; charset=utf-8"),
  ("js", "text/javascript; charset=utf-8"),
  ("mjs", "text/javascript; charset=utf-8"),
  ("json", "application/json; charset=utf-8"),
  ("map", "application/json; charset=utf-8"),
  ("svg", "image/svg+xml"),
  ("png", "image/png"),
  ("jpg", "image/jpeg"),
  ("jpeg", "image/jpeg"),
  ("gif", "image/gif"),
  ("webp", "image/webp"),
  ("avif", "image/avif"),
  ("ico", "image/x-icon"),
  ("woff", "font/woff"),
  ("woff2", "font/woff2"),
  ("ttf", "font/ttf"),
  ("txt", "text/plain; charset=utf-8"),
  ("xml", "application/xml; charset=utf-8"),
])

let plain = Dict.fromArray([("content-type", "text/plain; charset=utf-8")])

let extension = path =>
  switch String.lastIndexOf(path, ".") {
  | -1 => ""
  | at => String.slice(path, ~start=at + 1)->String.toLowerCase
  }

let channel = "/__minidoc"

// A build that lands says `reload` down the stream. A build that fails says
// `failed`, with what it printed: the page stays as it is and shows the
// failure at its foot, because a reload into a broken build loses the page.
let reload = "data: reload\n\n"
let failed = message => `event: failed\ndata: ${stringify(message)}\n\n`

// The page holds a stream open; a finished build says one word down it. A
// hidden page lets go of it: a browser allows a host six connections, so
// tabs left open would starve the next one, and an open stream keeps a page
// out of the back and forward cache. Shown again, it opens one anew.
let banner = "position:fixed;left:0;right:0;bottom:0;max-height:50vh;overflow:auto;margin:0;padding:12px 16px;background:#3b0a0a;color:#ffd9d9;font:12px/1.4 ui-monospace,monospace;white-space:pre-wrap;z-index:2147483647"
let live = `<script>(()=>{let s=null;const fail=e=>{let b=document.getElementById("__minidoc");if(!b){b=document.body.appendChild(Object.assign(document.createElement("pre"),{id:"__minidoc"}));b.style.cssText="${banner}"}b.textContent=JSON.parse(e.data)};const open=()=>{if(s)return;s=new EventSource("${channel}");s.addEventListener("message",()=>location.reload());s.addEventListener("failed",fail)};const close=()=>{if(s){s.close();s=null}};open();addEventListener("pagehide",close);addEventListener("pageshow",open);document.addEventListener("visibilitychange",()=>document.hidden?close():open())})()</script>`

let inject = html =>
  switch String.lastIndexOf(html, "</body>") {
  | -1 => html ++ live
  | at => String.slice(html, ~start=0, ~end=at) ++ live ++ String.slice(html, ~start=at)
  }

// `/guide/` -> its index, `/guide` -> `guide.html` then `guide/index.html`:
// what a static host answers, so the dev site is the deployed site.
let candidates = path =>
  if String.endsWith(path, "/") {
    [path ++ "index.html"]
  } else if extension(path) == "" {
    [path ++ ".html", path ++ "/index.html"]
  } else {
    [path]
  }

let serve = async (dir, clients: ref<array<res>>, broken: ref<option<string>>, req, res) => {
  let path = decode(target(req)->String.split("?")->Array.getUnsafe(0))
  if path == channel {
    head(
      res,
      200,
      Dict.fromArray([
        ("content-type", "text/event-stream"),
        ("cache-control", "no-cache"),
        ("connection", "keep-alive"),
      ]),
    )
    let _ = push(res, ":open\n\n")
    // A page opened while the build is broken is told at once.
    broken.contents->Option.forEach(message => push(res, failed(message))->ignore)
    clients := [...clients.contents, res]
    onClose(res, "close", () => clients := clients.contents->Array.filter(r => r !== res))
  } else if String.includes(path, "..") {
    head(res, 403, plain)
    finish(res, "Forbidden")
  } else {
    let wanted = candidates(path == "/" ? "/index.html" : path)
    let rec first = async i =>
      switch wanted->Array.get(i) {
      | None => None
      | Some(name) =>
        switch await readBytes(absolute(dir, String.slice(name, ~start=1))) {
        | Some(bytes) => Some((name, bytes))
        | None => await first(i + 1)
        }
      }
    switch await first(0) {
    | None =>
      head(res, 404, plain)
      finish(res, `Not found: ${path}`)
    | Some((name, bytes)) =>
      let kind = types->Dict.get(extension(name))->Option.getOr("application/octet-stream")
      head(res, 200, Dict.fromArray([("content-type", kind), ("cache-control", "no-store")]))
      // Only html carries the reload stream; everything else travels as bytes.
      if String.startsWith(kind, "text/html") {
        finish(res, inject(bytes->text("utf8")))
      } else {
        finish(res, bytes)
      }
    }
  }
}

// Resolves to the port bound, or -1 when the address is refused.
let rawListen: (server, int, string) => promise<int> = %raw(`(server, port, host) =>
  new Promise((resolve) => {
    const failed = () => {
      server.removeListener("listening", ready)
      resolve(-1)
    }
    const ready = () => {
      server.removeListener("error", failed)
      resolve(server.address().port)
    }
    server.once("error", failed)
    server.once("listening", ready)
    server.listen(port, host)
  })`)

// Whether a minidoc dev server answers at `port`: its reload channel opens an
// event stream. The stream is dropped as soon as its headers arrive.
let rawProbe: (string, int, string) => promise<bool> = %raw(`async (host, port, channel) => {
  const abort = new AbortController()
  const timer = setTimeout(() => abort.abort(), 1000)
  try {
    const res = await fetch("http://" + host + ":" + port + channel, {signal: abort.signal})
    return (res.headers.get("content-type") || "").startsWith("text/event-stream")
  } catch {
    return false
  } finally {
    clearTimeout(timer)
    abort.abort()
  }
}`)

// ---------------------------------------------------------------------------

type options = {
  root?: string,
  watch?: array<string>,
  ignore?: array<string>,
  extensions?: array<string>,
  serve?: string,
  port?: int,
}

/** What the runner cannot do itself: build, and remember a port. */
type hooks = {
  rebuild: unit => promise<unit>,
  readPort: unit => promise<option<int>>,
  writePort: int => promise<unit>,
}

type stopper = {stop: unit => unit}
type running = {port: int, stop: unit => unit}

let host = "127.0.0.1"

let watch = async (options: options, rebuild) => {
  let root = options.root->Option.getOr(cwd())
  let trigger = looper(rebuild, _ => ())
  await trigger()
  let watchers = await watching(
    [root, ...options.watch->Option.getOr([])],
    options.ignore->Option.getOr(ignored),
    options.extensions->Option.getOr(extensions),
    trigger,
  )
  say(`watching ${root}`)
  {stop: () => watchers->Array.forEach(unwatch)}
}

let dev = async (options: options, hooks: hooks) => {
  let root = options.root->Option.getOr(cwd())
  let dir = absolute(root, options.serve->Option.getOr("dist"))
  let clients: ref<array<res>> = ref([])
  let broken: ref<option<string>> = ref(None)
  let http: httpmod = await import_("node:http")
  let server = http.createServer((req, res) => serve(dir, clients, broken, req, res)->ignore)

  // A port the caller names is the caller's business. A port we remembered is
  // written down the first time, so this site keeps the same address
  // tomorrow. Either way it is never replaced: when it is taken by a dev
  // server, that server is this site's and we point at it; by anything else,
  // we fail loud.
  let remembered = switch options.port {
  | Some(port) => Some(port)
  | None => await hooks.readPort()
  }
  let wanted = remembered->Option.getOr(0)
  let port = await rawListen(server, wanted, host)
  if port < 0 {
    if wanted == 0 {
      fail(`dev server could not listen on ${host}`)
    } else if await rawProbe(host, wanted, channel) {
      say(`already running at http://${host}:${Int.toString(wanted)}`)
      {port: wanted, stop: () => ()}
    } else {
      fail(`port ${Int.toString(wanted)} is taken: free it, or pass another \`port\``)
    }
  } else {
    if options.port->Option.isNone && remembered != Some(port) {
      await hooks.writePort(port)
    }
    // The port is written before the first build, so the config a build reads
    // already names it — and before the watcher, so writing it is not a change.
    let trigger = looper(hooks.rebuild, failure => {
      broken := failure
      let word = switch failure {
      | None => reload
      | Some(message) => failed(message)
      }
      clients.contents->Array.forEach(r => push(r, word)->ignore)
    })
    await trigger()
    let watchers = await watching(
      [root, ...options.watch->Option.getOr([])],
      options.ignore->Option.getOr(ignored),
      options.extensions->Option.getOr(extensions),
      trigger,
    )
    say(`http://${host}:${Int.toString(port)} — watching ${root}`)
    {
      port,
      stop: () => {
        watchers->Array.forEach(unwatch)
        clients.contents->Array.forEach(r => finish(r, ""))
        // Kept-alive sockets would still answer on a port we gave up.
        shut(server)
        drop(server)
      },
    }
  }
}
