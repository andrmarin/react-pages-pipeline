# react-pages-pipeline

A minimal **Vite + React + TypeScript** single page that displays some text, the
app version, the active environment, and a few placeholder environment variables
(`AWS_KEY`, `AWS_SECRET`, `S3_BUCKET`). It ships with a **GitHub Actions release
pipeline** that deploys to **GitHub Pages** across three environments plus
on-demand feature-branch previews.

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

GitHub Pages serves a **single site per repo**, so every environment and every
feature preview is published into its **own subfolder** of the same Pages site
(on the `gh-pages` branch). Vite's `base` is set per deploy so assets resolve
correctly under each subfolder.

| Trigger | Environment | Published to |
| --- | --- | --- |
| Push to `develop` | `development` | `…/development/` |
| Push to `main` | `staging` | `…/staging/` |
| Push to `main` **that changes `version.txt`** | `production` | `…/production/` + git tag `v<version>` |
| Manual run on `main`/`develop` | chosen env | that env's subfolder |
| Manual run on a **feature branch** | chosen env (label only) | `…/feature-<branch>/` |

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
deploy the pipeline creates an immutable git tag `v<version>`. If that tag
already exists the production deploy **fails**, which guarantees you bumped the
version for every release and gives you a tagged commit to diff or roll back to.

**To cut a production release:** bump `version.txt` (e.g. `1.0.0` → `1.1.0`) and
push to `main`. This deploys staging *and* production, and tags `v1.1.0`.

### Deploy a feature branch manually

GitHub → **Actions** → **Deploy** → **Run workflow** → pick the **branch** and a
target **environment**. A feature branch publishes to `…/feature-<branch>/` so it
never overwrites a real environment.

---

## One-time GitHub setup

1. **Enable Pages.** Repo → **Settings → Pages** → *Build and deployment* →
   **Source: Deploy from a branch** → branch **`gh-pages`**, folder **`/ (root)`**.
   (The `gh-pages` branch is created automatically by the first deploy — run the
   workflow once, then set this.)

2. **Create the three Environments.** Repo → **Settings → Environments** → create
   `production`, `staging`, and `development`. For **each** one add:

   | Type | Name | Example value |
   | --- | --- | --- |
   | Variable | `AWS_KEY` | `AKIA...` (placeholder) |
   | Variable | `S3_BUCKET` | `my-bucket-name` |
   | Secret | `AWS_SECRET` | `placeholder-secret` |

   (Settings → Environments → *select env* → **Add variable** / **Add secret**.)

3. **(Recommended) Protect production.** On the `production` environment, add a
   **required reviewer** and/or restrict it to the `main` branch, so production
   deploys must be approved.

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
