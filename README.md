# react-pages-pipeline

[![production](https://img.shields.io/endpoint?url=https%3A%2F%2Fandrmarin.github.io%2Freact-pages-pipeline%2Fproduction%2Fversion.json)](https://andrmarin.github.io/react-pages-pipeline/production/)
[![staging](https://img.shields.io/endpoint?url=https%3A%2F%2Fandrmarin.github.io%2Freact-pages-pipeline%2Fstaging%2Fversion.json)](https://andrmarin.github.io/react-pages-pipeline/staging/)
[![development](https://img.shields.io/endpoint?url=https%3A%2F%2Fandrmarin.github.io%2Freact-pages-pipeline%2Fdevelopment%2Fversion.json)](https://andrmarin.github.io/react-pages-pipeline/development/)

<sub>Note: each badge reads `/<env>/version.json`, written by the deploy workflow, and updates as new versions ship.</sub>

## Overview

A minimal **Vite + React + TypeScript** single page that displays some text, the
app version, the active environment, and a few placeholder environment variables
(`AWS_KEY`, `AWS_SECRET`, `S3_BUCKET`). It ships with a **GitHub Actions release
pipeline** that deploys to **GitHub Pages** across three environments
(production / staging / development).

---

## Run locally

```bash
npm install
cp .env.example .env.local   # edit the placeholder values if you like
npm run dev                  # http://localhost:5173
```

Other scripts:

```bash
npm run build      # type-check (tsc) + production build into dist/
npm run preview    # serve the production build locally
npm run typecheck  # type-check only
```

`VITE_APP_VERSION` is read automatically from [`version.txt`](./version.txt) by
`vite.config.ts`, so you don't set it in `.env.local`.

### Git hooks (block direct commits to `main`)

Tracked hooks live in [`.githooks/`](./.githooks). Enable them once per clone:

```bash
bash scripts/install-hooks.sh   # sets core.hooksPath -> .githooks
```

The `pre-commit` hook rejects commits made directly on `main` (point your work at
a branch instead). It complements the **server-side** branch protection
(`scripts/protect-main.sh`) — the hook catches mistakes locally before they reach
GitHub. Emergency override: `ALLOW_PROTECTED_COMMIT=1 git commit ...`.
`bootstrap.sh` runs this automatically.

---

## How deployments work

GitHub Pages serves a **single site per repo**, so each environment is published
into its **own subfolder** of the same Pages site (on the `gh-pages` branch).
There are exactly three subfolders — `development`, `staging`, `production` —
and nothing else. Vite's `base` is set per deploy so assets resolve correctly
under each subfolder.

| Trigger | Deploys to | Version gate |
| --- | --- | --- |
| Push to `develop` | `development` | deploys **iff** `version.txt` > development's deployed version, else **skips** ✓ green |
| Push to `main` | `staging` **and** `production` | each deploys **iff** `version.txt` > *its own* deployed version, else **skips** ✓ green; production also tags `desktop-v<version>` |
| Manual run (any branch) | chosen env | **fails** ✗ unless `version.txt` > that env's deployed version |

**Every deploy must raise the version.** The gate compares `version.txt` against
the version currently deployed to the target environment (read from that env's
`version.json` on `gh-pages`). No bump → no deploy. See
[Versioning & the version gate](#versioning--the-version-gate).

URLs follow this pattern (lowercase owner):

```
https://<owner>.github.io/<repo>/<subfolder>/
e.g. https://<owner>.github.io/react-pages-pipeline/staging/
```

> The site **root** (`…/<repo>/`) has no page and will 404 — open one of the
> environment subfolders instead.

The pipeline is split in two workflows:

- [`.github/workflows/deploy.yml`](./.github/workflows/deploy.yml) — triggers and
  routing (branch → environment, manual dispatch).
- [`.github/workflows/build-deploy.yml`](./.github/workflows/build-deploy.yml) —
  reusable build + publish job (used once per environment, no duplication).

### Versioning & the version gate

[`version.txt`](./version.txt) is the single source of truth, and **every deploy
must raise it.** Each environment remembers the version it's running in its
`version.json` on `gh-pages` (the same file that powers the badge above). Before
building, the reusable workflow's **version gate** compares `version.txt` to that
baseline:

- `version.txt` **>** the env's deployed version (semver) → deploy proceeds.
- otherwise → **no deploy**: an automatic push **skips cleanly** (job stays green
  with a "Skipped — version not increased" summary); a manual run **fails** with
  a clear error.

The check is **per environment**, so you can promote the *same* version through
`development` → `staging` → `production`, but you can never redeploy a version an
environment already has. The job summary always shows `current → new` and whether
it deployed or skipped, so the outcome is obvious at a glance.

On a **production** deploy the pipeline also creates an immutable git tag
**`desktop-v<version>`**. The `desktop-` prefix is this project's name (passed as
`project: desktop` from [`deploy.yml`](./.github/workflows/deploy.yml)), so
multiple projects in the repo tag independently (e.g. `desktop-v1.0.0`,
`mobile-v2.3.1`).

**To ship a new version:** bump `version.txt` (e.g. `1.0.0` → `1.1.0`) and push
to `main` — staging and production each deploy `1.1.0` and production tags
`desktop-v1.1.0`. Pushes that don't bump the version simply don't deploy.

### Deploy any branch manually

GitHub → **Actions** → **Deploy** → **Run workflow** → pick the **branch** and a
target **environment**. The selected branch is built and published to that
environment's folder (`development` / `staging` / `production`), replacing
whatever was there — **but only if `version.txt` is greater than that env's
deployed version; otherwise the run fails**. Deploying to `production` also
creates the `desktop-v<version>` tag.

---

## One-time GitHub setup

The scripts in [`scripts/`](./scripts) automate this with the
[`gh` CLI](https://cli.github.com) (run `gh auth login` first). They run in any
bash shell — Git Bash, WSL, Linux, or macOS.

### One command (recommended)

From a fresh clone/copy of this folder, [`scripts/bootstrap.sh`](./scripts/bootstrap.sh)
does the whole thing end to end: `git init` + commit → create the GitHub repo →
create the 3 environments with their variables/secrets → push `main` (and
`develop`) to trigger the deploys → wait for `gh-pages` → enable Pages.

```bash
bash scripts/bootstrap.sh my-repo-name --public
```

Options: positional `repo` (`owner/name` or `name`, default = folder name),
`--public` / `--private` (default private), `--protect-prod` (required reviewer
on production), `--no-develop` (skip the develop branch). Requires `gh auth login`.

> Use `--public` on the free plan — GitHub Pages on a **private** repo needs a
> paid plan (Pro/Team/Enterprise).

### Step by step (if you already have a repo)

```bash
# 1. Create the 3 environments and set AWS_KEY + S3_BUCKET (vars) and
#    AWS_SECRET (secret) on each. Idempotent — safe to re-run.
#    Edit the placeholder values at the top of the script, or override via env vars.
bash scripts/setup-environments.sh                 # auto-detects the repo
bash scripts/setup-environments.sh --protect-prod  # also require a reviewer on production

# 2. After your first deploy has created the gh-pages branch, point Pages at it.
bash scripts/enable-pages.sh

# 3. (Optional) Protect main: block deletion, force-pushes, and direct pushes
#    (changes must go through a PR) + require linear history, enforced for admins.
bash scripts/protect-main.sh

# 4. (Optional) Squash-only merge policy: make "Squash and merge" the only way to
#    merge a PR (no merge/rebase commits), auto-delete the head branch on merge.
bash scripts/set-merge-policy.sh
```

Pass `--repo owner/name` to any script if you're not running from inside the
repo. `--protect-prod` adds a required reviewer + main-only branch policy to the
`production` environment (needs a public repo or a paid plan for private repos).
`scripts/protect-main.sh` also needs a public repo or a paid plan, and accepts
`--branch <name>` and `--reviews <N>` (default 0 required approvals).

Together, `protect-main.sh` (requires linear history) and `set-merge-policy.sh`
(squash-only) keep `main` a **clean, linear history with no merge commits** —
every PR collapses to a single commit titled after the PR.

### Manual (equivalent, via the UI)

1. **Create the three Environments.** Repo → **Settings → Environments** → create
   `production`, `staging`, and `development`. For **each** one add:

   | Type | Name | Example value |
   | --- | --- | --- |
   | Variable | `AWS_KEY` | `AKIA...` (placeholder) |
   | Variable | `S3_BUCKET` | `my-bucket-name` |
   | Secret | `AWS_SECRET` | `placeholder-secret` |

2. **Enable Pages.** Repo → **Settings → Pages** → *Build and deployment* →
   **Source: Deploy from a branch** → branch **`gh-pages`**, folder **`/ (root)`**.
   (The `gh-pages` branch is created automatically by the first deploy.)

3. **(Recommended) Protect production.** On the `production` environment, add a
   **required reviewer** and/or restrict it to the `main` branch.

4. **(Recommended) Squash-only merges.** Repo → **Settings → General → Pull
   Requests** → enable **Allow squash merging** only (uncheck merge & rebase),
   tick **Automatically delete head branches**. Then **Settings → Branches →
   main** → enable **Require linear history**.

No other secrets are needed — `GITHUB_TOKEN` is provided automatically and is
what publishes to the `gh-pages` branch.

---

## Notes & hardening ideas

- Actions are pinned to **major version tags** (`@v4`). For stricter supply-chain
  security, pin them to full commit SHAs.
- `peaceiris/actions-gh-pages` is used with `keep_files: true` so each deploy
  only updates its own subfolder. Because Vite fingerprints asset filenames,
  superseded files may linger in a subfolder over time; clear the `gh-pages`
  branch if you want a clean slate.
- To later deploy to **real AWS S3** instead of Pages, swap the *Publish to
  GitHub Pages* step in `build-deploy.yml` for an S3 sync step that uses
  `vars.AWS_KEY` / `secrets.AWS_SECRET` / `vars.S3_BUCKET`. The rest of the
  pipeline (environments, versioning, triggers) stays the same.
