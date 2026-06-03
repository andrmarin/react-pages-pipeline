#!/usr/bin/env bash
#
# Make "Squash and merge" the ONLY way to merge a PR, for a clean linear history
# (no merge commits in the git graph). Also auto-deletes the head branch on merge
# and sets the squash commit to use the PR title + body.
#
# This sets repository-level merge options. Pair it with scripts/protect-main.sh,
# which adds required_linear_history on main as a backstop.
#
# Requirements: gh CLI authenticated; admin on the repo.
#
# Usage: bash scripts/set-merge-policy.sh [--repo owner/name]
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

command -v gh >/dev/null || { echo "gh CLI not found — https://cli.github.com" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not authenticated — run: gh auth login" >&2; exit 1; }

if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) \
    || { echo "Could not detect the repo. Pass --repo owner/name" >&2; exit 1; }
fi

echo "Setting merge policy on $REPO to squash-only…"

gh api --method PATCH "repos/$REPO" \
  -H "Accept: application/vnd.github+json" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -F squash_merge_commit_title=PR_TITLE \
  -F squash_merge_commit_message=PR_BODY \
  >/dev/null

echo "Done. PRs can now ONLY be squash-merged:"
echo "  - squash merge:  enabled (only option)"
echo "  - merge commit:  disabled (no 'Merge' commits in the graph)"
echo "  - rebase merge:  disabled"
echo "  - head branch:   auto-deleted on merge"
echo "  - squash commit: titled from the PR title, body from the PR description"
