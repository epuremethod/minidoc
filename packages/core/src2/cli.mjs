#!/usr/bin/env node
// `minidoc <folder>`: serve each markdown file of the folder as a page,
// with the editor. The croquis of the next minidoc.
//
// One React and one tilia serve the server and the editor, which is linked
// from ../editor with node_modules of its own: the hook resolves each shared
// package from this package, before anything imports React.
import { register } from "node:module";

register("./one.mjs", import.meta.url);

const folder = process.argv[2];
if (!folder) {
  console.error("Usage: minidoc <folder>");
  process.exit(1);
}
await import("./dom.mjs");
const { serve } = await import("./serve.mjs");
await serve(folder);
