# Microfrontend build pipeline

This repo builds 8 formsflow.ai microfrontend packages (`forms-flow-admin`, `forms-flow-components`,
`forms-flow-integration`, `forms-flow-nav`, `forms-flow-review`, `forms-flow-service`,
`forms-flow-submissions`, `forms-flow-theme`) into a **single combined image**, matching the pattern
used by [RSBC's fork](https://github.com/bcgov/rsbc-forms-flow-ai-micro-front-ends) of this same
upstream project — not 9+ separate images.

## Developer workflow

1. Make your change inside the relevant package directory (e.g. `forms-flow-nav/`).
2. Push to a branch other than `main`. The matching per-package CI workflow (e.g.
   `forms-flow-nav-ci.yml`) runs automatically, checking your package still builds cleanly —
   it does **not** build or affect any other package.
3. Bump the root `VERSION` file if this should ship as a new version (the combined image is tagged
   from this single file — all 8 packages currently share one version, they aren't versioned
   independently).
4. Open a PR into `main`. Once merged, `forms-flow-microfrontend-cd.yml` triggers automatically
   (only if your changed paths match one of the 8 package directories, `webpack.formio.js`,
   `Dockerfile`, `nginx.conf`, or `VERSION`) and builds+pushes the **combined** image to
   `ghcr.io/bcgov/jag-servebc-forms-flow-ai-micro-front-ends:<VERSION>` (and `:latest`).
5. **Redeploying to OpenShift is a separate, manual step** — this pipeline does not auto-deploy.
   After a new image is pushed, roll it out in the target namespace:
   ```bash
   oc set image deployment/forms-flow-microfrontend forms-flow-microfrontend=ghcr.io/bcgov/jag-servebc-forms-flow-ai-micro-front-ends:<VERSION> -n <namespace>
   # or, if the Deployment is pinned to :latest with imagePullPolicy: Always:
   oc rollout restart deployment/forms-flow-microfrontend -n <namespace>
   ```

## Why one combined image, not 8

`forms-flow-web-root-config` (the actual page users load) references each microfrontend by a
build-time URL like `https://<host>/forms-flow-nav@<version>/forms-flow-nav.js`. Bundling everything
into one image with one nginx server (serving each package's build output from a versioned
subdirectory, see the root `Dockerfile`/`nginx.conf`) means only **one** OpenShift Deployment/Route to
manage, instead of one per package — this is deliberately the same approach RSBC uses in production,
not something invented for this fork.

## Workflow files

- `ci-workflow.yml` — reusable; lint/test/build-check for a single package directory. Called by each
  `forms-flow-<package>-ci.yml`.
- `cd-workflow.yml` — reusable; generic Docker build-and-push to `ghcr.io`, authenticated via the
  auto-provided `GITHUB_TOKEN` (no registry secrets to create or manage). Called by
  `forms-flow-microfrontend-cd.yml`.
- `forms-flow-microfrontend-cd.yml` — the actual trigger: builds the **whole repo root** as the Docker
  context (not a single package) on merge to `main`, or via manual `workflow_dispatch`.
- `forms-flow-<package>-ci.yml` (×8) — per-package PR validation only, no image is built or pushed
  from these.

## Known gaps, not yet set up

- No automated deploy-on-push to OpenShift (see step 5 above — still manual).
- The `ghcr.io` package's visibility (public/private) hasn't been explicitly confirmed after the
  first real push from this pipeline — if it ends up private, the OpenShift `Deployment` will need an
  `imagePullSecret` added (a GitHub Personal Access Token with `read:packages` scope, `docker-registry`
  secret type) — not required if the package is public.
- `bump-release-version.yml` and `release-orchestrator.yml` (inherited from the upstream
  `AOT-Technologies/forms-flow-ai-micro-front-ends` fork point) are unrelated to this pipeline and
  untouched — not reviewed for whether they still make sense for this fork's workflow.
