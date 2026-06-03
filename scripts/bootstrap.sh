#!/usr/bin/env bash
#
# End-to-end bootstrap: turn this folder into a live GitHub repo with the full
# deployment pipeline running.
#
# Steps:
#   1. git init + initial commit (if not already a repo)
#   2. create the GitHub repo and wire up the 'origin' remote
#   3. create the 3 environments + variables/secrets (setup-environments.sh)
#   4. push main    -> triggers staging + initial production deploy (tag v<version>)
#   5. push develop -> triggers development deploy
#   6. wait for the gh-pages branch, then enable Pages (enable-pages.sh)
#
# Requirements: gh CLI authenticated (gh auth login), git.
#
# Usage:
#   bash scripts/bootstrap.sh [repo] [--public|--private] [--protect-prod] [--no-develop]
#     repo   owner/name or name (default: current directory name)
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)" # repo root (scripts/..)
cd "$HERE"

REPO=""
VISIBILITY="--private"
PROTECT_PROD=false
MAKE_DEVELOP=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --public) VISIBILITY="--public"; shift ;;
    --private) VISIBILITY="--private"; shift ;;
    --protect-prod) PROTECT_PROD=true; shift ;;
    --no-develop) MAKE_DEVELOP=false; shift ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^#\s\{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) REPO="$1"; shift ;;
  esac
done

# --- Preflight ---------------------------------------------------------------
command -v gh  >/dev/null || { echo "gh CLI not found — https://cli.github.com" >&2; exit 1; }
command -v git >/dev/null || { echo "git not found" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not authenticated — run: gh auth login" >&2; exit 1; }

[[ -n "$REPO" ]] || REPO="$(basename "$HERE")"
echo "Target repo: $REPO   (visibility: ${VISIBILITY#--})"
if [[ "$VISIBILITY" == "--private" ]]; then
  echo "Note: GitHub Pages on a PRIVATE repo needs a paid plan (Pro/Team/Enterprise)."
  echo "      Use --public if you're on the free plan and want Pages to serve."
fi

# --- 1. git init + initial commit -------------------------------------------
[[ -d .git ]] || git init -q
git rev-parse HEAD >/dev/null 2>&1 || git checkout -q -B main

# Ensure a commit identity exists for this repo (only sets it if unset).
git config user.name  >/dev/null 2>&1 || git config user.name  "$(gh api user --jq .login)"
git config user.email >/dev/null 2>&1 || \
  git config user.email "$(gh api user --jq .id)+$(gh api user --jq .login)@users.noreply.github.com"

git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "Initial commit: React app + GitHub Pages release pipeline"
else
  git rev-parse HEAD >/dev/null 2>&1 || git commit -q --allow-empty -m "Initial commit"
fi

# --- 2. create the GitHub repo + remote -------------------------------------
if git remote get-url origin >/dev/null 2>&1; then
  echo "Remote 'origin' already configured: $(git remote get-url origin)"
else
  gh repo create "$REPO" $VISIBILITY --source=. --remote=origin
fi
# Normalize to the canonical owner/name from the created repo.
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

# --- 3. environments (before first deploy, so vars/secrets are present) ------
SETUP_ARGS=(--repo "$REPO")
$PROTECT_PROD && SETUP_ARGS+=(--protect-prod)
bash "$HERE/scripts/setup-environments.sh" "${SETUP_ARGS[@]}"

# --- 4. push main (triggers staging + initial production) --------------------
echo "Pushing main…"
git push -u origin main

# --- 5. develop branch (triggers development) --------------------------------
if $MAKE_DEVELOP; then
  echo "Creating and pushing develop…"
  git checkout -q -B develop
  git push -u origin develop
  git checkout -q main
fi

# --- 6. install local git hooks (block direct commits to main) ---------------
# Done after the initial main commit/push so it can't block bootstrap itself.
bash "$HERE/scripts/install-hooks.sh"

# --- 7. wait for gh-pages, then enable Pages ---------------------------------
echo "Waiting for the first deploy to create the gh-pages branch (up to ~5 min)…"
for _ in $(seq 1 30); do
  if gh api "repos/$REPO/branches/gh-pages" >/dev/null 2>&1; then
    bash "$HERE/scripts/enable-pages.sh" --repo "$REPO"
    echo
    echo "Bootstrap complete 🎉"
    exit 0
  fi
  sleep 10
done

echo
echo "The gh-pages branch isn't ready yet. Check the deploy:  gh run list --repo $REPO"
echo "Once it finishes, enable Pages with:  bash scripts/enable-pages.sh --repo $REPO"
