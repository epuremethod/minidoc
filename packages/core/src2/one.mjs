// One React, one tilia: the editor is linked from ../editor with
// node_modules of its own. Each shared package resolves from this package,
// whoever imports it. Registered by the CLI before anything imports React.
const shared = /^(react|react-dom|tilia|@tilia\/react|@rescript\/react|@rescript\/runtime)(\/.*)?$/;
const here = new URL("../package.json", import.meta.url).href;

export async function resolve(specifier, context, next) {
  return shared.test(specifier) ? next(specifier, { ...context, parentURL: here }) : next(specifier, context);
}
