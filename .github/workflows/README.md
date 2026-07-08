# Terraform CI/CD on GitHub Actions (Azure)

Passwordless (OIDC) pipeline that plans and applies the Terraform in `terraform/`
to Azure, with IaC linting, security scanning, PR plan comments, and
environment-gated applies.

## Workflows

| File | Trigger | Does |
| --- | --- | --- |
| `terraform-ci.yml` | PR to `main` | `fmt` → `tflint` → Trivy IaC scan → `validate` → **plan** dev+test, posted as PR comments |
| `terraform-ci.yml` | push to `main` | **plan dev → approve → apply dev → plan test → approve → apply test** |
| `terraform-ci.yml` | manual dispatch | plan the chosen env; apply only if `mode=apply` (after approval) |
| `terraform-destroy.yml` | manual dispatch | guarded destroy: type env to confirm → **plan (destroy) → approve → apply** |
| `terraform-reusable.yml` | (called by the above) | shared job with a `plan` / `apply` **mode** |

## Plan-then-approve (why apply is a separate job)

A GitHub Environment approval gate pauses a job **before its first step** — so a
combined plan+apply job would ask for approval *before* the plan runs. Instead
the flow is split:

1. **plan** job (ungated, `<env>-plan` environment): init → fmt → tflint → Trivy
   → validate → `plan -out=tfplan`. The plan is shown in the **job summary**
   (and PR comment) and uploaded as an **artifact**.
2. **apply** job (`needs` the plan job, protected `<env>` environment): the
   approval happens here — *after* you've read the plan — then it
   `terraform apply`s the **exact** uploaded plan (no re-plan, no drift).

## Security properties

- **No stored credentials** — Azure auth uses GitHub OIDC → Entra federated
  identity. Nothing but non-secret IDs live in GitHub.
- **State via AAD** — `ARM_USE_AZUREAD=true`, so the backend uses tokens, not
  storage account keys.
- **Least-privilege `GITHUB_TOKEN`** — explicit `permissions:` blocks.
- **Plan/apply consistency** — apply consumes the exact saved `tfplan`.
- **Approval gates** — applies run in protected GitHub Environments.
- **Concurrency lock** — one run per environment at a time (matches TF state lock).
- **Supply chain** — IaC scanned by Trivy (SARIF → code scanning). Pin actions to
  SHAs + enable Dependabot for `github-actions` for maximum hardening.

---

## One-time setup

Prereqs: the remote state backend already exists (`make tf-bootstrap` created
`rg-tfstate-emp` / your storage account / `tfstate` container).

Set these shell variables first:

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
GH_ORG="<your-github-org-or-user>"
GH_REPO="employee-management"
STATE_RG="rg-tfstate-emp"
STATE_SA="<your-state-storage-account>"   # e.g. sttfemp1dfe38
```

### 1. Create the CI identity (Entra app + service principal)

```bash
APP_ID=$(az ad app create --display-name "gh-${GH_REPO}-terraform" --query appId -o tsv)
az ad sp create --id "$APP_ID"
SP_OID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
```

### 2. Grant least-privilege roles

```bash
# Create/manage infra (AKS, VNet, ACR, Key Vault, ...)
az role assignment create --assignee "$APP_ID" --role "Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}"

# Needed because the config creates role assignments (azurerm_role_assignment)
az role assignment create --assignee "$APP_ID" --role "User Access Administrator" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}"

# Read/write Terraform state via AAD (no storage keys)
az role assignment create --assignee "$APP_ID" --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${STATE_RG}/providers/Microsoft.Storage/storageAccounts/${STATE_SA}"
```

> Scope `Contributor`/`User Access Administrator` to a resource group instead of
> the whole subscription if you can — but the chart creates its own RGs, so
> subscription scope is simplest for a POC.

### 3. Add federated credentials (one per GitHub Environment the jobs use)

The jobs run in these environments: `dev`, `test` (apply) and `dev-plan`,
`test-plan` (plan). Create a federated credential for each:

```bash
for ENVNAME in dev test dev-plan test-plan; do
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"gh-env-${ENVNAME}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GH_ORG}/${GH_REPO}:environment:${ENVNAME}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
done
```

### 4. Create the GitHub Environments

In **Settings → Environments**, create:

- `dev`, `test` — add **Required reviewers** (this is the apply approval gate).
- `dev-plan`, `test-plan` — no protection (plan-only, so PRs don't need approval).

### 5. Add GitHub repository **Variables**

**Settings → Secrets and variables → Actions → Variables** (these are IDs, not
secrets):

| Variable | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | `$APP_ID` |
| `AZURE_TENANT_ID` | `$TENANT_ID` |
| `AZURE_SUBSCRIPTION_ID` | `$SUBSCRIPTION_ID` |
| `TFSTATE_RG` | `rg-tfstate-emp` |
| `TFSTATE_SA` | your state storage account (e.g. `sttfemp1dfe38`) |
| `TFSTATE_CONTAINER` | `tfstate` |

No GitHub **secrets** are required — auth is fully OIDC.

---

## Day-to-day flow

1. Open a PR that changes `terraform/**` → the pipeline plans **dev** and **test**
   and comments both plans on the PR.
2. Get review + merge to `main` → **apply-dev** runs and waits at the `dev`
   environment approval; approve → it applies. Then **apply-test** waits at the
   `test` approval; approve → it applies.
3. Need an ad-hoc apply? **Actions → terraform-ci → Run workflow** and pick the
   environment.
4. Teardown? **Actions → terraform-destroy → Run workflow**, choose the env, and
   type its name to confirm (still gated by approval).

## Hardening checklist (optional, recommended)

- Pin every `uses:` to a full commit SHA; enable **Dependabot** for `github-actions`.
- Add **branch protection** on `main` (required PR review + required status checks).
- Use **separate CI identities per environment** (repeat step 1–3 per env, and
  move the `AZURE_CLIENT_ID` variable to the GitHub Environment scope).
- Turn on **required reviewers** and **wait timers** on `test`/prod environments.

---

# Application CI — `ci.yml` (DevSecOps gated build)

Security-gated build pipeline for the app images. Each stage must pass before the
next runs; **push + sign happen only on `main`** (PRs stop after the image scan).

```
1 GitLeaks (secrets)  →  2 SonarQube (SAST)  →  3 SCA (Trivy dependency scan)
     →  4 test (pytest + frontend build)  →  5 build + Trivy image scan
     →  6 push to ACR **and** Docker Hub  →  7 cosign sign (keyless)
```

Enterprise properties:
- **Passwordless** — Azure/ACR via OIDC; **keyless** cosign signing (Sigstore/Fulcio,
  no keys to manage). Verify later with the workflow's OIDC identity.
- **Hard gates** — GitLeaks (any leak), Sonar **quality gate**, Trivy **SCA** (fixable HIGH/CRITICAL),
  Trivy `exit-code 1` on fixable CRITICAL. Findings (SCA) go to the **Security** tab.
- **Scan before push** — images are built and Trivy-scanned locally; only clean
  images are pushed, then signed by digest.
- **Immutable tags** — `:<VERSION>` and `:git-<sha>`.

### Dual-registry publish (resilient)

The publish stage pushes each image to **both ACR and Docker Hub, independently**:

- If **one** registry is unavailable/misconfigured → the job logs a **⚠ warning**
  ("… unavailable") and **continues** with the other. Non-fatal.
- The job **fails only if BOTH** registries fail (or, of course, if the Trivy gate
  finds a CRITICAL). Scanning stages always fail hard.
- A registry is simply skipped if its config is absent — ACR when
  `ACR_LOGIN_SERVER` is unset, Docker Hub when `DOCKERHUB_USERNAME` is unset.

## Setup

Federated credential for the `main` branch is already created (subject
`repo:<owner>/<repo>:ref:refs/heads/main`), and the CI identity has AcrPush.

Add these in **Settings → Secrets and variables → Actions**:

| Kind | Name | Value / notes |
| --- | --- | --- |
| Variable | `ACR_LOGIN_SERVER` | e.g. `acrempdevyykge.azurecr.io` — *unset to skip ACR* |
| Variable | `ACR_NAME` | e.g. `acrempdevyykge` |
| Variable | `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` | (already set) |
| Variable | `DOCKERHUB_USERNAME` | your Docker Hub username — *unset to skip Docker Hub* |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub access token (hub.docker.com → Account Settings → **Personal access tokens** → Read/**Write**) |
| Secret | `SONAR_TOKEN` | SonarCloud token (host is hardcoded to `sonarcloud.io`) |
| Secret | `GITLEAKS_LICENSE` | *(only for GitHub orgs)* |

### SonarCloud (SonarQube Cloud) — free for public repos

1. Go to **https://sonarcloud.io** → sign in with GitHub.
2. **+ → Analyze new project** → import `Siddhuge/Emp-Mgmt-3-Tier-App`.
3. **Administration → Analysis Method → turn OFF "Automatic Analysis"** and select
   **CI** (otherwise CI scans conflict with automatic analysis).
4. Copy the **Organization Key** and **Project Key** shown on the setup page into
   `sonar-project.properties` (currently `siddhuge` / `Siddhuge_Emp-Mgmt-3-Tier-App`
   — adjust if yours differ).
5. **My Account → Security → Generate token** → add it as the `SONAR_TOKEN` secret.

## Verify a signed image (keyless)

```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/<owner>/<repo>/.github/workflows/ci.yml@refs/heads/main" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  <ACR>/backend:<version>
```

---

# Continuous Deployment — `cd.yml` (Helm to AKS)

Deploys the exact commit `ci.yml` built, scanned, and signed — to AKS via Helm —
and gates promotion between environments on **DAST** (dynamic security testing
against the live deployment), not just static scans.

```
CI succeeds on main
  → dry-run dev  → [approve] → deploy dev  → smoke test → DAST → tag dev-dast-approved
  → dry-run test → [approve] → deploy test → smoke test → DAST → tag test-dast-approved
       (dry-run test refuses to proceed unless the image is dev-dast-approved)

Manual dispatch (any environment, any previously-built commit)
  → dry-run chosen env → [approve] → deploy chosen env → smoke test → DAST → tag
```

## Why dry-run and deploy are separate jobs

Same reason as the Terraform pipeline: a GitHub Environment approval gate pauses
a job **before its first step**, so approval must happen *after* a reviewable
diff exists, not before. `cd-reusable.yml` runs in one of two modes:

1. **dry-run** (ungated `<env>-plan` environment) — resolves the registry,
   verifies signatures, runs `helm upgrade --dry-run --debug`. Output goes to
   the job summary.
2. **deploy** (`needs` the dry-run job, protected `<env>` environment) —
   approval happens here, then it bootstraps cluster prerequisites and runs the
   real `helm upgrade --atomic --wait`, followed by `helm test` as a smoke test.

## What makes this enterprise-grade

- **No stale config** — AKS/Key Vault/ACR resource names are **discovered at
  runtime** via `az` queries scoped to `rg-emp-<env>` (never hardcoded GitHub
  Variables). This project hit real pain from Terraform re-applies regenerating
  random name suffixes (ACR, Key Vault) — discovery makes CD immune to that.
- **Deploys an exact, immutable commit** — uses the `git-<sha>` image tag (not
  the mutable `:<version>` tag), so every deploy is tied to one auditable
  commit; rollback = redeploy any previously-built SHA.
- **Supply-chain verified** — before every dry-run *and* every deploy (not
  cached from earlier in the pipeline — approvals can sit for hours), it
  re-verifies each image's **cosign signature** against the CI workflow's OIDC
  identity. An unsigned or tampered image is never deployed, even if a
  same-tag image exists in a registry.
- **Resilient dual-registry** — mirrors the CI pipeline's philosophy: prefers
  ACR (same-cloud, no pull secret) and falls back to Docker Hub automatically
  (creating/refreshing the `dockerhub-pull-secret` in-namespace) if ACR is
  unavailable — the same "notify, don't fail" pattern as `ci.yml`.
- **Automatic rollback on failure** — `--atomic` makes Helm roll back to the
  last good revision if the upgrade or its readiness checks fail.
- **DAST-gated promotion** — dev must pass a live OWASP ZAP scan before its
  image can be promoted to test (digest-verified, not just tag presence); test
  runs its own DAST pass again after deploying. See "DAST gate" below.
- **Self-sufficient cluster bootstrap** — idempotently ensures ingress-nginx,
  cert-manager + ClusterIssuers, and the CoreDNS AKS-hairpin fix are present,
  so CD can stand up a brand-new AKS cluster with no manual pre-steps.
- **No new Azure setup required** — reuses the exact GitHub
  Environments/federated credentials already created for Terraform (`dev`,
  `test`, `dev-plan`, `test-plan`) and the same `AZURE_CLIENT_ID` identity.

## DAST gate and promotion tags

After every real deploy, `cd-reusable.yml` runs **OWASP ZAP** against the live
deployment and only proceeds if it passes:

- **Target**: the backend's OpenAPI spec (`https://employee.<env>.sidhuge.xyz/openapi.json`)
  — ZAP's `openapi` job imports it and exercises every real endpoint at least
  once, then a **passive-only** scan runs (no active/attack job — see
  [`dast/zap-plan.template.yaml`](../../dast/zap-plan.template.yaml) for exactly
  what runs and why). It won't fuzz inputs or mutate app data.
- **Gate**: fails on any **High**-risk alert (matches the severity bar used
  everywhere else in this pipeline). ZAP's own `exitStatus` job sets the
  process exit code, so it fails the step directly — same pattern as the Trivy
  gates in `ci.yml`.
- **Report**: HTML + SARIF uploaded as a workflow artifact
  (`dast-report-<env>-<sha>`), 30-day retention.
- **On pass**: the exact image digest is tagged `dev-dast-approved` (or
  `test-dast-approved`) and pushed to **both** ACR and Docker Hub — warns and
  continues if one registry fails, fails the run only if **both** fail (same
  resilience rule as `ci.yml`'s image push).
- **Promotion gate**: before test's dry-run *or* deploy, the pipeline compares
  `digest(backend:git-<sha>)` against `digest(backend:dev-dast-approved)`. A
  commit that hasn't passed dev's DAST (or whose approval has since been
  superseded by a newer commit — these are **rolling** tags, always pointing at
  the latest approved commit) cannot be promoted to test.
- **Known limitation (v1)**: the scan is unauthenticated. Endpoints requiring a
  JWT mostly return 401, so behind-auth business logic isn't deeply exercised
  yet — still valuable for headers/TLS/CORS/info-disclosure-style checks.
  Adding a login step + token injection to the ZAP plan is a natural follow-up.

## Prerequisites

1. **AKS must already exist** for the target environment (`make tf-apply
   TF_ENV=dev`). The dry-run job fails fast with a clear message if
   `rg-emp-<env>` doesn't exist.
2. **DNS** — `employee.<env>.sidhuge.xyz` must resolve to that environment's
   ingress LoadBalancer IP (same prerequisite as reaching the app normally;
   DAST scans this public URL).
3. Same GitHub **Variables/Secrets** as `ci.yml` (`AZURE_CLIENT_ID/TENANT_ID/
   SUBSCRIPTION_ID`, `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, optionally
   `ACR_LOGIN_SERVER`/`ACR_NAME`) — already set if `ci.yml` is working.
4. *(Optional, once ACR exists again)* grant the CI identity `AcrPull` so CD can
   verify/pull from ACR — Contributor alone does **not** include ACR data-plane
   actions. Set `ci_identity_principal_id` in `terraform/*.tfvars`:
   ```hcl
   ci_identity_principal_id = "830a38d5-c555-41a1-b254-2895d64ddec5"  # the CI SP's object id
   ```

## Manual deploy / redeploy / promote a hotfix

**Actions → cd → Run workflow** → pick `environment`, optionally set `git_sha`
to redeploy any previously-built commit (defaults to latest `main`). Useful for
redeploying test independently of dev, or re-running a deploy that failed for
an infra reason (cluster was still coming up, etc.) without re-running CI.

## Rollback — `cd-rollback.yml`

Failed deploys already auto-rollback (`--atomic`). For an **intentional**
rollback of a deploy that succeeded but is now considered bad:

**Actions → cd-rollback → Run workflow** → pick environment, optionally a
specific Helm revision (blank = previous), type the environment name to
confirm (guarded, mirrors `terraform-destroy.yml`) → approve → rolls back +
smoke tests.
