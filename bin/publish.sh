#!/bin/bash

set -e

# ============================================ UTILS and basic CHECKS

# Set up environment
if ! command -v pnpm &>/dev/null; then
  echo "pnpm is not installed. Please install it first."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: There are uncommitted changes in the repository."
  echo "Please commit or stash your changes before proceeding."
  exit 1
else
  echo "Repository is clean. Proceeding with the operation."
fi

is_semver() {
  local version="$1"
  # Regex for SemVer compliance
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?(\+[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?$ ]]; then
    echo "Valid SemVer: $version"
    return 0
  else
    echo "Invalid SemVer: $version"
    return 1
  fi
}

DATE=$(date +'%Y%m%dT%H%M%S')

# Install dependencies
pnpm i
# Rebuild
pnpm build

VERSION=$(npm pkg get version | sed 's/"//g')
is_semver "$VERSION"

# ============================================ PUBLISH

# Update version if publishing beta (--beta argument)
if [[ $1 == "--beta" ]]; then
  VERSION=$VERSION-beta.$DATE
fi

npm --no-git-tag-version version $VERSION

if [[ $1 == "--beta" ]]; then
  pnpm publish --tag beta --access public --no-git-checks
else
  pnpm publish --access public --no-git-checks
  git tag "v$VERSION"
fi

# Reset git repo
git reset --hard HEAD

if [[ $1 == "--beta" ]]; then
  echo "Beta version published successfully!"
else
  echo "Published successfully!"
fi
