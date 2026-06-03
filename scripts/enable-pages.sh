#!/usr/bin/env bash
#
# Enable GitHub Pages serving from the gh-pages branch (root folder).
#
# Run this AFTER the first successful deploy — the deploy workflow is what
# creates the gh-pages branch, and Pages can only point at a branch that exists.
#
# Requirements: gh CLI authenticated (gh auth login).
#
# Usage:
#   bash scripts/enable-pages.sh [--repo owner/name]
#
set -euo pipefail

REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^#\s\{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

command -v gh >/dev/null || { echo "gh CLI not found — install from https://cli.github.com" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not authenticated — run: gh auth login" >&2; exit 1; }

if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) \
    || { echo "Could not detect the repo. Pass --repo owner/name" >&2; exit 1; }
fi

# Fail early with a clear message if gh-pages doesn't exist yet.
if ! gh api "repos/$REPO/branches/gh-pages" >/dev/null 2>&1; then
  echo "The 'gh-pages' branch does not exist yet." >&2
  echo "Push the repo and run the Deploy workflow once, then re-run this script." >&2
  exit 1
fi

echo "Enabling Pages for $REPO (source: gh-pages /)"
BODY='{"source":{"branch":"gh-pages","path":"/"}}'
if gh api "repos/$REPO/pages" >/dev/null 2>&1; then
  # Pages already configured — update the source.
  gh api --method PUT "repos/$REPO/pages" --input - <<<"$BODY" --silent
else
  gh api --method POST "repos/$REPO/pages" --input - <<<"$BODY" --silent
fi

OWNER=$(gh api "repos/$REPO" --jq .owner.login | tr '[:upper:]' '[:lower:]')
NAME=$(basename "$REPO")
echo "Pages enabled."
echo "Environment URLs:"
for sub in production staging development; do
  echo "  $sub: https://$OWNER.github.io/$NAME/$sub/"
done
