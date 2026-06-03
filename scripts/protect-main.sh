#!/usr/bin/env bash
#
# Protect the main branch: block deletion, block force-pushes, and require all
# changes to go through a pull request (no direct pushes). Enforced for admins too.
#
# Requirements: gh CLI authenticated. Branch protection needs a public repo, or
# a private repo on a paid plan (Pro/Team/Enterprise).
#
# Usage:
#   bash scripts/protect-main.sh [--repo owner/name] [--branch main] [--reviews N]
#
set -euo pipefail

REPO=""
BRANCH="main"
REVIEWS=0 # required approving reviews; 0 still forces a PR but allows self-merge
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --reviews) REVIEWS="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^#\s\{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

command -v gh >/dev/null || { echo "gh CLI not found — https://cli.github.com" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not authenticated — run: gh auth login" >&2; exit 1; }

if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) \
    || { echo "Could not detect the repo. Pass --repo owner/name" >&2; exit 1; }
fi

echo "Protecting '$BRANCH' on $REPO (require PR, no force-push, no deletion)…"

if ! gh api --method PUT "repos/$REPO/branches/$BRANCH/protection" \
  -H "Accept: application/vnd.github+json" \
  --input - >/dev/null <<EOF
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": $REVIEWS },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
then
  echo "FAILED. Branch protection requires a public repo, or a private repo on a" >&2
  echo "paid plan (Pro/Team/Enterprise). Check the repo visibility/plan." >&2
  exit 1
fi

echo "Done. '$BRANCH' is now protected:"
echo "  - deletion blocked"
echo "  - force-pushes blocked"
echo "  - direct pushes blocked (changes require a pull request)"
echo "  - linear history required (no merge commits)"
echo "  - rules enforced for admins too"
echo
echo "Tip: run scripts/set-merge-policy.sh to make squash the only merge button."
