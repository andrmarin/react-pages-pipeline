# react-pages-pipeline

[![production](https://img.shields.io/endpoint?url=https%3A%2F%2Fandrmarin.github.io%2Freact-pages-pipeline%2Fproduction%2Fversion.json)](https://andrmarin.github.io/react-pages-pipeline/production/)
[![staging](https://img.shields.io/endpoint?url=https%3A%2F%2Fandrmarin.github.io%2Freact-pages-pipeline%2Fstaging%2Fversion.json)](https://andrmarin.github.io/react-pages-pipeline/staging/)
[![development](https://img.shields.io/endpoint?url=https%3A%2F%2Fandrmarin.github.io%2Freact-pages-pipeline%2Fdevelopment%2Fversion.json)](https://andrmarin.github.io/react-pages-pipeline/development/)

<sub>Each badge reads `/<env>/version.json`, written by the deploy workflow, and updates as new versions ship.</sub>

A minimal **Vite + React + TypeScript** single page that displays some text, the
app version, the active environment, and a few placeholder environment variables
(`AWS_KEY`, `AWS_SECRET`, `S3_BUCKET`). It ships with a **GitHub Actions release
pipeline** that deploys to **GitHub Pages** across three environments
(production / staging / development).

> ⚠️ **Security note.** Everything passed as a `VITE_*` variable is baked into
> the static JavaScript bundle and is **publicly visible** in the browser. The
> AWS values here are placeholders. `AWS_SECRET` is stored as a GitHub *secret*
> only to demonstrate the secrets plumbing — never expose a real secret in a
> client-side build.

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

---

## How deployments work

GitHub Pages serves a **single site per repo**, so each environment is published
into its **own subfolder** of the same Pages site (on the `gh-pages` branch).
There are exactly three subfolders — `development`, `staging`, `production` —
and nothing else. Vite's `base` is set per deploy so assets resolve correctly
under each subfolder.

| Trigger | Environment | Published to |
| --- | --- | --- |
| Push to `develop` | `development` | `…/development/` |
| Push to `main` | `staging` | `…/staging/` |
| Push to `main` **that changes `version.txt`** | `production` | `…/production/` + git tag `desktop-v<version>` |
| Manual run (any branch) | chosen env | that env's folder |

URLs follow this pattern (lowercase owner):

```
https://<owner>.github.io/<repo>/<subfolder>/
e.g. https://<owner>.github.io/react-pages-pipeline/staging/
```

> The site **root** (`…/<repo>/`) has no page and will 404 — open one of the
> environment subfolders instead.

The pipeline is split in two workflows:

- [`.github/workflows/deploy.yml`](./.github/workflows/deploy.yml) — triggers and
  routing (branch → environment, manual dispatch, version-bump detection).
- [`.github/workflows/build-deploy.yml`](./.github/workflows/build-deploy.yml) —
  reusable build + publish job (used once per environment, no duplication).

### Versioning & release tags

[`version.txt`](./version.txt) is the single source of truth. On a **production**
deploy the pipeline creates an immutable git tag **`desktop-v<version>`** — the
`desktop-` prefix is this project's name, so multiple projects in the repo tag
independently (e.g. `desktop-v1.0.0`, `mobile-v2.3.1`). If that tag already
exists the production deploy **fails**, which guarantees you bumped the version
for every release and gives you a tagged commit to diff or roll back to.

The project name is passed to the reusable workflow as `project: desktop` from
every call in [`deploy.yml`](./.github/workflows/deploy.yml); a new project gets
its own `deploy.yml` with a different name.

**To cut a production release:** bump `version.txt` (e.g. `1.0.0` → `1.1.0`) and
push to `main`. This deploys staging *and* production, and tags `desktop-v1.1.0`.

### Deploy any branch manually

GitHub → **Actions** → **Deploy** → **Run workflow** → pick the **branch** and a
target **environment**. The selected branch is built and published to that
environment's folder (`development` / `staging` / `production`), replacing
whatever was there. Deploying to `production` also creates the `desktop-v<version>` tag.

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
#    (changes must go through a PR), enforced for admins too.
bash scripts/protect-main.sh
```

Pass `--repo owner/name` to any script if you're not running from inside the
repo. `--protect-prod` adds a required reviewer + main-only branch policy to the
`production` environment (needs a public repo or a paid plan for private repos).
`scripts/protect-main.sh` also needs a public repo or a paid plan, and accepts
`--branch <name>` and `--reviews <N>` (default 0 required approvals).

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
