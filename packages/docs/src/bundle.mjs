// The dev page's editor, bundled for the browser into `<out>/edit.js` and
// `edit.css`. Only `dev.mjs` and the Chrome check bundle it: the site's
// build never does.
import { fileURLToPath } from "node:url";
import esbuild from "esbuild";

// The editor is linked from ../editor, with node_modules of its own. One
// React, one tilia and one runtime serve the page: @minidoc/live's.
const live = fileURLToPath(new URL("../../live/", import.meta.url));
const shared = /^(react|react-dom|tilia|@tilia\/react|@rescript\/react|@rescript\/runtime)(\/.*)?$/;
const one = {
  name: "one-copy",
  setup(build) {
    build.onResolve({ filter: shared }, (args) =>
      args.pluginData === "shared" ? undefined : build.resolve(args.path, { kind: args.kind, resolveDir: live, pluginData: "shared" }),
    );
  },
};

/** The bundle's options, writing into `out`. */
export const bundle = (out) => ({
  entryPoints: { edit: fileURLToPath(new URL("./edit.mjs", import.meta.url)) },
  outdir: out,
  bundle: true,
  format: "esm",
  sourcemap: true,
  logLevel: "warning",
  define: { "process.env.NODE_ENV": '"development"' },
  plugins: [one],
});

/** Bundle once, or keep bundling as the sources change. */
export async function bundled(out, { watch = false } = {}) {
  if (!watch) return esbuild.build(bundle(out));
  const context = await esbuild.context(bundle(out));
  await context.watch();
  return context;
}
