#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage: $0 <core|blocks|deprecated> [--beta]"
  exit 1
}

package="${1:-}"
mode="${2:-stable}"

# A stable publish tags the commit: core keeps the `v0.2.0` tags it had
# before the workspace, blocks gets its own prefix, and the former name,
# which only re-exports core, gets no tag.
case "$package" in
  core) prefix="v" ;;
  blocks) prefix="blocks-v" ;;
  deprecated) prefix="" ;;
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

git_tag="${prefix:+$prefix$base_version}"
if [ "$mode" = "stable" ] && [ -n "$git_tag" ] &&
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

# `pnpm build` (run by prepack) writes dist/llms.txt and dist/llms-full.txt
# from the docs guide: make sure they made it into the tarball.
if [ "$package" = "core" ]; then
  mkdir -p "$work/packs"
  pnpm pack --pack-destination "$work/packs"
  for file in llms.txt llms-full.txt; do
    tar -tzf "$work"/packs/*.tgz | grep -qx "package/dist/$file"
  done
fi

pnpm publish --tag "$tag" --access public --no-git-checks

if [ "$package" = "deprecated" ] && [ "$mode" = "stable" ]; then
  npm deprecate "$name" "Renamed to @minidoc/core."
fi

if [ "$mode" = "stable" ] && [ -n "$git_tag" ]; then
  git tag "$git_tag"
fi

echo "Published $name at $version ($tag)."
