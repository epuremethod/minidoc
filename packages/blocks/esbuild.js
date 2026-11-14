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

esbuild
  .build({
    entryPoints: ["src/index.js"],
    bundle: true,
    sourcemap: true,
    minify: false,
    target: ["esnext"],
    ignoreAnnotations: true,
    packages: "external",
    format: "esm",
    outfile: "dist/index.mjs",
    plugins: [copyFile("./src/index.d.ts", "./dist/index.d.ts")],
  })
  .catch((e) => {
    console.log(e);
    process.exit(1);
  });
