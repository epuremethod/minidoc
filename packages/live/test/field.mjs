// A stand-in for a host's text field, such as maia's `TiliaEditor.Line`:
// a `contenteditable` span with no class and no look of its own, which
// keeps typed spaces and draws marks as markdown-it does, as bare
// `<strong>`, `<em>`, `<code>` and `<a href>`. It keeps the props and the
// handle that `@minidoc/live` asks of a host's field. It does not format
// markdown as it is typed: the scenarios and the hit check need only the
// contract and the look.

import { createElement, useImperativeHandle, useLayoutEffect, useRef } from "react";

const escape = (text) => text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

/** A line's markdown as HTML: code, links, bold and italic. An empty line draws a `<br>`, so the caret has a line. */
export function html(markdown) {
  if (markdown === "") return "<br>";
  const parts = markdown.split(/(`[^`]+`)/);
  return parts
    .map((part) => {
      if (/^`[^`]+`$/.test(part)) return `<code>${escape(part.slice(1, -1))}</code>`;
      return escape(part)
        .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, text, href) => `<a href="${href.replaceAll('"', "&quot;")}">${text}</a>`)
        .replace(/(\*\*|__)(.+?)\1/g, "<strong>$2</strong>")
        .replace(/(\*|_)(.+?)\1/g, "<em>$2</em>");
    })
    .join("");
}

/** The markdown a line's DOM holds. */
export function markdownOf(element) {
  let markdown = "";
  for (const node of element.childNodes) {
    if (node.nodeType === 3) markdown += node.textContent;
    else if (node.nodeType !== 1 || node.localName === "br") continue;
    else if (node.textContent === "") continue;
    else if (node.localName === "strong") markdown += `**${markdownOf(node)}**`;
    else if (node.localName === "em") markdown += `*${markdownOf(node)}*`;
    else if (node.localName === "code") markdown += `\`${node.textContent}\``;
    else if (node.localName === "a") markdown += `[${markdownOf(node)}](${node.getAttribute("href")})`;
    else markdown += markdownOf(node);
  }
  return markdown;
}

/** The text before the caret, as shown, or `undefined` when the caret is not in the element or a selection is made. */
export function before(element) {
  const selection = element.ownerDocument.getSelection();
  if (selection === null || selection.rangeCount === 0 || !selection.isCollapsed) return undefined;
  if (!element.contains(selection.anchorNode)) return undefined;
  const range = element.ownerDocument.createRange();
  range.selectNodeContents(element);
  range.setEnd(selection.anchorNode, selection.anchorOffset);
  return range.toString();
}

/** The line cut at the caret, in markdown, without the space at the cut. With no caret in it, the caret is at its end. */
function cut(element) {
  const selection = element.ownerDocument.getSelection();
  if (selection === null || selection.rangeCount === 0 || !element.contains(selection.anchorNode)) {
    return { before: markdownOf(element), after: "" };
  }
  const selected = selection.getRangeAt(0);
  const half = (start) => {
    const range = element.ownerDocument.createRange();
    range.selectNodeContents(element);
    if (start) range.setEnd(selected.startContainer, selected.startOffset);
    else range.setStart(selected.endContainer, selected.endOffset);
    return markdownOf(range.cloneContents());
  };
  return { before: half(true).trimEnd(), after: half(false).trimStart() };
}

/** Put the caret at an offset of the text as shown. */
export function place(element, offset) {
  const document = element.ownerDocument;
  const walker = document.createTreeWalker(element, 4);
  let left = offset;
  let node = walker.nextNode();
  const range = document.createRange();
  range.selectNodeContents(element);
  range.collapse(offset === 0);
  while (node !== null) {
    if (left <= node.textContent.length) {
      range.setStart(node, left);
      range.collapse(true);
      break;
    }
    left -= node.textContent.length;
    node = walker.nextNode();
  }
  const selection = document.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
}

export function Field({ markdown, onChange, onEnter, onBackspaceAtStart, onLeave, ref }) {
  const line = useRef(null);
  useLayoutEffect(() => {
    const drawn = line.current.firstChild !== null;
    if (!drawn || markdownOf(line.current) !== markdown) line.current.innerHTML = html(markdown);
  }, [markdown]);
  useImperativeHandle(ref, () => ({
    focus(at) {
      line.current.focus();
      const length = line.current.textContent.length;
      place(line.current, at === "start" ? 0 : at === "end" ? length : Math.min(at, length));
    },
  }));
  return createElement("span", {
    ref: line,
    contentEditable: true,
    suppressContentEditableWarning: true,
    spellCheck: false,
    style: { whiteSpace: "pre-wrap" },
    onInput: () => onChange(markdownOf(line.current)),
    onBlur: () => onLeave(),
    onKeyDown: (event) => {
      if (event.nativeEvent.isComposing || event.keyCode === 229) return;
      if (event.key === "Enter") {
        event.preventDefault();
        onEnter(cut(line.current));
      } else if (event.key === "Backspace" && before(line.current) === "") {
        event.preventDefault();
        onBackspaceAtStart();
      } else if (event.key === "Escape") line.current.blur();
    },
  });
}
