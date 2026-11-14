import esbuild from "esbuild";
import { copyFileSync } from "fs";

function copyFile(sourceFile, targetFile) {
  return {
    name: "copy-file",
    setup(build) {
      build.onEnd(() => copyFileSync(sourceFile, targetFile));
    },
  };
}

// Every package stays external, but sury's ReScript module: sury ships it
// compiled with a suffix of its own, so the `S.mjs` that ReScript writes
// beside it here exists only after a ReScript build. Its own import of
// `sury` stays external.
const external = {
  name: "external",
  setup(build) {
    build.onResolve({ filter: /^[^./]/ }, (args) =>
      args.kind === "entry-point" || args.path.startsWith("sury/src/") ? undefined : { path: args.path, external: true },
    );
  },
};

esbuild
  .build({
    entryPoints: ["src/index.js"],
    bundle: true,
    sourcemap: true,
    minify: false,
    target: ["esnext"],
    ignoreAnnotations: true,
    format: "esm",
    outfile: "dist/index.mjs",
    plugins: [external, copyFile("./src/index.d.ts", "./dist/index.d.ts")],
  })
  .catch((e) => {
    console.log(e);
    process.exit(1);
  });
