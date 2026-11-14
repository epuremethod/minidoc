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

// Two entries, the live components and the page editor, which share one
// copy of Live in a chunk.
esbuild
  .build({
    entryPoints: { index: "src/index.js", edit: "src/edit.js" },
    bundle: true,
    splitting: true,
    sourcemap: true,
    minify: false,
    target: ["esnext"],
    ignoreAnnotations: true,
    packages: "external",
    format: "esm",
    outdir: "dist",
    outExtension: { ".js": ".mjs" },
    chunkNames: "[name]-[hash]",
    plugins: [
      copyFile("./src/index.d.ts", "./dist/index.d.ts"),
      copyFile("./src/edit.d.ts", "./dist/edit.d.ts"),
    ],
  })
  .catch((e) => {
    console.log(e);
    process.exit(1);
  });
