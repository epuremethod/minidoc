#!/bin/bash

set -euo pipefail

if ! command -v pnpm >/dev/null; then
  echo "pnpm is not installed."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "The repository must be clean before publishing."
  exit 1
fi

mode="${1:-stable}"
case "$mode" in
  stable) tag="latest" ;;
  --beta) tag="beta" ;;
  *)
    echo "Usage: $0 [--beta]"
    exit 1
    ;;
esac

base_version=$(node -p "require('./package.json').version")
if [[ ! "$base_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Package version must be stable SemVer: $base_version"
  exit 1
fi

if [ "$mode" = "stable" ] && git rev-parse -q --verify "refs/tags/v$base_version" >/dev/null; then
  echo "Tag v$base_version already exists: bump the version first."
  exit 1
fi

version="$base_version"
work=$(mktemp -d)
cp package.json "$work/package.json"

cleanup() {
  cp "$work/package.json" package.json
  rm -rf "$work"
}
trap cleanup EXIT

# Stable publishes the version already in package.json: `npm version` refuses
# a no-op bump, so only beta rewrites it.
if [ "$mode" != "stable" ]; then
  version="$base_version-${tag}.$(date +'%Y%m%dT%H%M%S')"
  npm --no-git-tag-version version "$version"
fi

pnpm install --frozen-lockfile
pnpm check

# `pnpm build` (run by prepack) writes dist/llms.txt and dist/llms-full.txt
# from the docs guide: make sure they made it into the tarball.
mkdir -p "$work/packs"
pnpm pack --pack-destination "$work/packs"
for file in llms.txt llms-full.txt; do
  tar -tzf "$work"/packs/*.tgz | grep -qx "package/dist/$file"
done

pnpm publish --tag "$tag" --access public --no-git-checks

if [ "$mode" = "stable" ]; then
  git tag "v$version"
fi

echo "Published @epure/minidoc at $version ($tag)."
