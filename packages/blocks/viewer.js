// The viewer: a drawing opens full screen when it is clicked, and ‹ › step
// through every drawing of the page. A site adds it to its layout once,
// beside blocks.css:
//
//   <script src="./viewer.js" defer></script>
//
// `data-select` on the script tag names the blocks that open, as a CSS
// selector. It defaults to the drawn blocks: sequences, state machines and
// database models. The viewer is the browser's own dialog, so Escape closes
// it and focus stays inside while it is open.

(() => {
  const script = document.currentScript
  const select = script?.dataset.select || ".sequence, .states, .model"

  // The styles come first in the head, so a site's own stylesheet overrides
  // them, except where the copy of a block must fill the screen: those rules
  // name the dialog too, to outweigh the block's own. Colours are the blocks theme's, with plain ones where no theme is.
  const style = `
.viewer-opens { cursor: zoom-in; }
.viewer-opens:focus-visible { outline: 2px solid var(--blocks-stroke, #8c9198); outline-offset: 4px; }
.viewer { width: 100vw; height: 100dvh; max-width: none; max-height: none; margin: 0; padding: 0; border: 0; background: var(--blocks-canvas, #faf9f6); color: var(--blocks-ink, #202a38); }
.viewer[open] { display: grid; grid-template-rows: auto minmax(0, 1fr); }
.viewer::backdrop { background: var(--blocks-canvas, #faf9f6); }
.viewer__bar { display: flex; align-items: center; gap: 1em; padding: .6em 1em; border-bottom: 1px solid var(--blocks-line, #c9ccd0); font-size: 14px; font-weight: 600; line-height: 1.4; }
.viewer__count { flex: 1; color: var(--blocks-muted, #626770); font-variant-numeric: tabular-nums; }
.viewer__close, .viewer__step { display: grid; place-items: center; width: 2.4rem; height: 2.4rem; padding: 0; border: 1px solid var(--blocks-line, #c9ccd0); border-radius: 50%; background: var(--blocks-surface, #fff); color: var(--blocks-ink, #202a38); cursor: pointer; }
.viewer__icon { display: block; width: 1rem; height: 1rem; fill: none; stroke: currentColor; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
.viewer__close:hover, .viewer__step:hover { border-color: var(--blocks-ink, #202a38); }
.viewer__step { position: fixed; top: 50%; translate: 0 -50%; }
.viewer__step--previous { left: 1rem; }
.viewer__step--next { right: 1rem; }
.viewer__step[hidden] { display: none; }
.viewer__stage { display: flex; min-height: 0; padding: 2rem 4.5rem; cursor: zoom-out; }
.viewer__stage a { cursor: pointer; }
.viewer .viewer__stage > * { display: flex; flex-direction: column; flex: 1; min-width: 0; min-height: 0; margin: 0; overflow: visible; }
.viewer .viewer__stage svg { flex: 1; width: 100%; height: 100%; min-height: 0; max-width: none; max-height: none; }
@media (max-width: 640px) { .viewer__stage { padding: 1rem 1rem 4.5rem; } .viewer__step { top: auto; bottom: 1rem; translate: none; } }
`

  // The signs on the buttons are drawn, not typed: a font sits a glyph on its
  // baseline, and a chevron then stands below the middle of its circle.
  const icon = (d) => `<svg class="viewer__icon" viewBox="0 0 16 16" aria-hidden="true"><path d="${d}" /></svg>`

  function start() {
    const blocks = [...document.querySelectorAll(select)].filter((block) => !block.closest(".viewer"))
    if (blocks.length === 0) return

    const sheet = document.createElement("style")
    sheet.textContent = style
    document.head.prepend(sheet)

    const dialog = document.createElement("dialog")
    dialog.className = "viewer"
    dialog.setAttribute("aria-label", "Drawing, full screen")
    dialog.innerHTML = `<div class="viewer__bar"><span class="viewer__count" aria-live="polite"></span><button type="button" class="viewer__close" aria-label="Close">${icon("M4 4 12 12M12 4 4 12")}</button></div>
<div class="viewer__stage"></div>
<button type="button" class="viewer__step viewer__step--previous" aria-label="Previous drawing">${icon("M10 3 5 8l5 5")}</button>
<button type="button" class="viewer__step viewer__step--next" aria-label="Next drawing">${icon("M6 3l5 5-5 5")}</button>`
    document.body.append(dialog)
    const stage = dialog.querySelector(".viewer__stage")
    const count = dialog.querySelector(".viewer__count")
    const steps = dialog.querySelectorAll(".viewer__step")
    for (const step of steps) step.hidden = blocks.length === 1

    let at = 0
    const show = (index) => {
      at = (index + blocks.length) % blocks.length
      const block = blocks[at]
      const copy = block.cloneNode(true)
      for (const name of ["tabindex", "role", "aria-label", "aria-haspopup"]) copy.removeAttribute(name)
      copy.classList.remove("viewer-opens")
      stage.replaceChildren(copy)
      // A theme sets its variables on an ancestor of the block, and the dialog
      // hangs from the body: it carries the block's theme itself.
      const themed = block.closest("[data-blocks-theme]")
      if (themed) dialog.dataset.blocksTheme = themed.dataset.blocksTheme
      else delete dialog.dataset.blocksTheme
      count.textContent = blocks.length === 1 ? "" : `${at + 1} / ${blocks.length}`
    }
    const open = (index) => {
      show(index)
      if (!dialog.open) dialog.showModal()
    }

    blocks.forEach((block, index) => {
      const name = block.querySelector("[aria-label]")?.getAttribute("aria-label")
      block.classList.add("viewer-opens")
      block.tabIndex = 0
      block.setAttribute("role", "button")
      block.setAttribute("aria-haspopup", "dialog")
      block.setAttribute("aria-label", name ? `${name}, open full screen` : "Open full screen")
      block.addEventListener("click", (event) => {
        if (event.target.closest("a")) return
        open(index)
      })
      block.addEventListener("keydown", (event) => {
        if (event.key !== "Enter" && event.key !== " ") return
        event.preventDefault()
        open(index)
      })
    })

    dialog.querySelector(".viewer__close").addEventListener("click", () => dialog.close())
    steps[0].addEventListener("click", () => show(at - 1))
    steps[1].addEventListener("click", () => show(at + 1))
    dialog.addEventListener("keydown", (event) => {
      if (event.key === "ArrowLeft") show(at - 1)
      else if (event.key === "ArrowRight") show(at + 1)
      else return
      event.preventDefault()
    })
    // A click on the drawing or beside it closes it, as a click on the
    // backdrop would. A link in the drawing still follows.
    stage.addEventListener("click", (event) => {
      if (!event.target.closest("a")) dialog.close()
    })
    // Closed, the page shows the last drawing viewed.
    dialog.addEventListener("close", () => {
      stage.replaceChildren()
      blocks[at].focus()
    })

    window.minidocViewer = { open, close: () => dialog.close() }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start)
  else start()
})()
