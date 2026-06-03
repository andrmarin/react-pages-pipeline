#!/usr/bin/env bash
#
# Point this clone's git at the repo's tracked hooks (.githooks). Run once per
# clone. Hooks live under .githooks so they're version-controlled and shared.
#
# Usage: bash scripts/install-hooks.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Not inside a git repository." >&2
  exit 1
}

git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true

echo "Installed git hooks (core.hooksPath -> .githooks)."
echo "Active hooks: $(ls .githooks 2>/dev/null | tr '\n' ' ')"
