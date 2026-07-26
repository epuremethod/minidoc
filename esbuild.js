import esbuild from "esbuild";
import { copyFileSync } from "fs";

const copyTypes = {
  name: "copy-types",
  setup(build) {
    build.onEnd(() => copyFileSync("./src/Minidoc.res.d.mts", "./dist/index.d.ts"));
  },
};

const build = {
  entryPoints: ["src/Minidoc.res.mjs"],
  bundle: true,
  sourcemap: true,
  target: ["esnext"],
  // tilia is inlined: its compiled-in-source files only exist after a
  // ReScript build, so the published bundle cannot import them. The other
  // deps ship the deep files the emitted imports point to.
  external: ["yaml", "marked", "sury", "sury/*", "@rescript/runtime", "@rescript/runtime/*"],
  plugins: [copyTypes],
};

esbuild.build({ ...build, format: "esm", outfile: "dist/index.mjs" }).catch((e) => {
  console.log(e);
  process.exit(1);
});
