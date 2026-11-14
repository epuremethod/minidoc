// A document for the server. Live splits a drawing's HTML with a
// `<template>`, which needs a `document`; on the server, linkedom gives one.
// A croquis workaround: live should split HTML without a document.
import { parseHTML } from "linkedom";

if (typeof globalThis.document === "undefined") {
  globalThis.document = parseHTML("<!doctype html><html><head></head><body></body></html>").document;
}
