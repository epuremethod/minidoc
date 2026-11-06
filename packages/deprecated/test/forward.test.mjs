import assert from "node:assert/strict";
import test from "node:test";
import * as core from "@minidoc/core";
import * as former from "../index.mjs";

test("the former name hands over the same module as @minidoc/core", () => {
  assert.deepEqual(Object.keys(former).sort(), Object.keys(core).sort());
  for (const name of Object.keys(core)) assert.equal(former[name], core[name], name);
});
