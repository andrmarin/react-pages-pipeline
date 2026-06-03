#!/usr/bin/env bash
#
# Create the production / staging / development GitHub Environments for this repo
# and populate each with the AWS_KEY + S3_BUCKET variables and the AWS_SECRET
# secret. Idempotent — safe to re-run (it overwrites existing values).
#
# Requirements:
#   - gh CLI (https://cli.github.com), authenticated:  gh auth login
#   - Run from inside the repo, OR pass --repo owner/name
#
# Usage:
#   bash scripts/setup-environments.sh [--repo owner/name] [--protect-prod]
#
# The values below are PLACEHOLDERS. Edit them, or export overrides before
# running, e.g.:  PROD_S3_BUCKET=real-bucket bash scripts/setup-environments.sh
#
set -euo pipefail

# --- Placeholder values (edit me, or override via the env vars on the right) ---
declare -A AWS_KEY=(
  [development]="${DEV_AWS_KEY:-AKIA_DEV_PLACEHOLDER}"
  [staging]="${STAGING_AWS_KEY:-AKIA_STAGING_PLACEHOLDER}"
  [production]="${PROD_AWS_KEY:-AKIA_PROD_PLACEHOLDER}"
)
declare -A S3_BUCKET=(
  [development]="${DEV_S3_BUCKET:-my-bucket-development}"
  [staging]="${STAGING_S3_BUCKET:-my-bucket-staging}"
  [production]="${PROD_S3_BUCKET:-my-bucket-production}"
)
declare -A AWS_SECRET=(
  [development]="${DEV_AWS_SECRET:-dev-secret-placeholder}"
  [staging]="${STAGING_AWS_SECRET:-staging-secret-placeholder}"
  [production]="${PROD_AWS_SECRET:-prod-secret-placeholder}"
)

ENVIRONMENTS=(development staging production)

# --- Args --------------------------------------------------------------------
REPO=""
PROTECT_PROD=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --protect-prod) PROTECT_PROD=true; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^#\s\{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# --- Preflight ---------------------------------------------------------------
command -v gh >/dev/null || { echo "gh CLI not found — install from https://cli.github.com" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not authenticated — run: gh auth login" >&2; exit 1; }

if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) \
    || { echo "Could not detect the repo. Pass --repo owner/name" >&2; exit 1; }
fi
echo "Repository: $REPO"
echo

# --- Create environments + set variables/secrets ----------------------------
for env in "${ENVIRONMENTS[@]}"; do
  echo "==> Environment: $env"
  gh api --method PUT "repos/$REPO/environments/$env" --silent
  gh variable set AWS_KEY   --repo "$REPO" --env "$env" --body "${AWS_KEY[$env]}"
  gh variable set S3_BUCKET --repo "$REPO" --env "$env" --body "${S3_BUCKET[$env]}"
  gh secret   set AWS_SECRET --repo "$REPO" --env "$env" --body "${AWS_SECRET[$env]}"
  echo "    set variables: AWS_KEY, S3_BUCKET   |   secret: AWS_SECRET"
done

# --- Optional: protect production -------------------------------------------
if $PROTECT_PROD; then
  echo
  echo "==> Protecting 'production' (required reviewer = you, deploys limited to main)"
  USER_ID=$(gh api user --jq .id)
  if gh api --method PUT "repos/$REPO/environments/production" --input - >/dev/null <<EOF
{
  "reviewers": [{ "type": "User", "id": $USER_ID }],
  "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true }
}
EOF
  then
    gh api --method POST "repos/$REPO/environments/production/deployment-branch-policies" \
      -f name="main" >/dev/null 2>&1 || true
    echo "    protection applied"
  else
    echo "    WARN: could not apply protection — environment rules require a public repo"
    echo "          or a paid plan (Pro/Team/Enterprise) for private repos. Skipping."
  fi
fi

echo
echo "Done. Environments ready: ${ENVIRONMENTS[*]}"
echo "Tip: after your first deploy creates the gh-pages branch, run scripts/enable-pages.sh"
