#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [major|minor|patch]"
  exit 1
}

[[ $# -eq 1 ]] || usage
bump_type="$1"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
version_file="$repo_root/VERSION"
[[ -f "$version_file" ]] || { echo "VERSION file not found: $version_file"; exit 1; }

current="$(tr -d '[:space:]' < "$version_file")"
IFS='.' read -r major minor patch <<< "$current"

case "$bump_type" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  *)
    usage
    ;;
esac

next="${major}.${minor}.${patch}"
printf '%s\n' "$next" > "$version_file"

echo "Bumped VERSION: $current -> $next"
echo "Remember to update CHANGELOG.md before commit."
