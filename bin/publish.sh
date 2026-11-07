#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage: $0 <minidoc|blocks> [--beta]"
  exit 1
}

package="${1:-}"
mode="${2:-stable}"

# A stable publish tags the commit: minidoc keeps the `v0.1.1` tags it had
# before the workspace, and blocks gets its own prefix.
case "$package" in
  minidoc) prefix="v" ;;
  blocks) prefix="blocks-v" ;;
  *) usage ;;
esac

case "$mode" in
  stable) tag="latest" ;;
  --beta) tag="beta" ;;
  *) usage ;;
esac

if ! command -v pnpm >/dev/null; then
  echo "pnpm is not installed."
  exit 1
fi

root=$(cd "$(dirname "$0")/.." && pwd)
dir="$root/packages/$package"
cd "$root"

if [ -n "$(git status --porcelain)" ]; then
  echo "The repository must be clean before publishing."
  exit 1
fi

name=$(node -p "require('$dir/package.json').name")
base_version=$(node -p "require('$dir/package.json').version")
if [[ ! "$base_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Package version must be stable SemVer: $base_version"
  exit 1
fi

git_tag="$prefix$base_version"
if [ "$mode" = "stable" ] &&
  git rev-parse -q --verify "refs/tags/$git_tag" >/dev/null; then
  echo "Tag $git_tag already exists: bump the version first."
  exit 1
fi

version="$base_version"
work=$(mktemp -d)
cp "$dir/package.json" "$work/package.json"

cleanup() {
  cp "$work/package.json" "$dir/package.json"
  rm -rf "$work"
}
trap cleanup EXIT

# Stable publishes the version already in package.json: `npm version` refuses
# a no-op bump, so only beta rewrites it.
if [ "$mode" != "stable" ]; then
  version="$base_version-${tag}.$(date +'%Y%m%dT%H%M%S')"
  (cd "$dir" && npm --no-git-tag-version version "$version")
fi

pnpm install --frozen-lockfile
pnpm check

cd "$dir"

# The tarball holds what each subpath needs. For minidoc, `pnpm build` (run
# by prepack) writes dist/llms.txt and dist/llms-full.txt from the docs
# guide, and `/edit` is compiled in src/edit.
case "$package" in
  minidoc) shipped="dist/index.mjs dist/llms.txt dist/llms-full.txt src/edit/Edit.res.mjs edit.css" ;;
  blocks) shipped="src/Blocks.res.mjs blocks.css src/live/Live.res.mjs live.css" ;;
esac
mkdir -p "$work/packs"
pnpm pack --pack-destination "$work/packs"
for file in $shipped; do
  if ! tar -tzf "$work"/packs/*.tgz | grep -qx "package/$file"; then
    echo "The tarball lacks $file."
    exit 1
  fi
done

pnpm publish --tag "$tag" --access public --no-git-checks

if [ "$mode" = "stable" ]; then
  git tag "$git_tag"
fi

echo "Published $name at $version ($tag)."
