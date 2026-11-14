#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage: $0 <core|blocks|live|all> [--beta]"
  exit 1
}

target="${1:-}"
mode="${2:-stable}"

# `all` publishes blocks first, then core, then live, which depends on
# blocks.
case "$target" in
  core | blocks | live) packages=("$target") ;;
  all) packages=(blocks core live) ;;
  *) usage ;;
esac

case "$mode" in
  stable) tag="latest" ;;
  --beta) tag="beta" ;;
  *) usage ;;
esac

# A stable publish tags the commit: core keeps the `v0.1.1` tags minidoc had
# before the workspace, and blocks and live get their own prefix.
prefix() {
  case "$1" in
    core) echo "v" ;;
    blocks) echo "blocks-v" ;;
    live) echo "live-v" ;;
  esac
}

# What each tarball must hold: the bundle of each entry, its types, the
# compiled sources and the stylesheets. For core, `pnpm build` (run by
# prepack) writes dist/llms.txt and dist/llms-full.txt from the docs guide.
shipped() {
  case "$1" in
    core) echo "dist/index.mjs dist/index.d.ts dist/llms.txt dist/llms-full.txt src/index.js src/Minidoc.mjs rescript.json" ;;
    blocks) echo "dist/index.mjs dist/index.d.ts src/index.js src/Blocks.mjs rescript.json blocks.css themes/soft.css viewer.js" ;;
    live) echo "dist/index.mjs dist/index.d.ts dist/edit.mjs dist/edit.d.ts src/index.js src/Live.mjs src/edit/Edit.mjs rescript.json live.css edit.css" ;;
  esac
}

if ! command -v pnpm >/dev/null; then
  echo "pnpm is not installed."
  exit 1
fi

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

if [ -n "$(git status --porcelain)" ]; then
  echo "The repository must be clean before publishing."
  exit 1
fi

work=$(mktemp -d)
cleanup() {
  for package in "${packages[@]}"; do
    if [ -f "$work/$package.json" ]; then
      cp "$work/$package.json" "$root/packages/$package/package.json"
    fi
  done
  rm -rf "$work"
}
trap cleanup EXIT

# Every version is set before anything is published, so that live depends
# on the blocks version published with it, a beta's included.
stamp=$(date +'%Y%m%dT%H%M%S')
for package in "${packages[@]}"; do
  dir="$root/packages/$package"
  cp "$dir/package.json" "$work/$package.json"
  base_version=$(node -p "require('$dir/package.json').version")
  if [[ ! "$base_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "The version of $package must be stable SemVer: $base_version"
    exit 1
  fi
  git_tag="$(prefix "$package")$base_version"
  if [ "$mode" = "stable" ] &&
    git rev-parse -q --verify "refs/tags/$git_tag" >/dev/null; then
    echo "Tag $git_tag already exists: bump the version of $package first."
    exit 1
  fi
  # Stable publishes the version already in package.json: `npm version`
  # refuses a no-op bump, so only beta rewrites it.
  if [ "$mode" != "stable" ]; then
    (cd "$dir" && npm --no-git-tag-version version "$base_version-$tag.$stamp" >/dev/null)
  fi
done

pnpm install --frozen-lockfile
pnpm check

for package in "${packages[@]}"; do
  dir="$root/packages/$package"
  cd "$dir"
  name=$(node -p "require('./package.json').name")
  version=$(node -p "require('./package.json').version")

  mkdir -p "$work/packs/$package"
  pnpm pack --pack-destination "$work/packs/$package"
  archive=$(ls "$work"/packs/"$package"/*.tgz)
  for file in $(shipped "$package"); do
    if ! tar -tzf "$archive" | grep -qx "package/$file"; then
      echo "The tarball of $name lacks $file."
      exit 1
    fi
  done
  if tar -xzOf "$archive" package/package.json | grep -q '"devDependencies"'; then
    echo "The tarball of $name keeps its devDependencies."
    exit 1
  fi

  pnpm publish --tag "$tag" --access public --no-git-checks

  if [ "$mode" = "stable" ]; then
    git tag "$(prefix "$package")$version"
  fi

  echo "Published $name at $version ($tag)."
done
