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
1 GitLeaks (secrets)  →  2 SonarQube (SAST)  →  3 OWASP Dependency-Check (SCA)
     →  4 test (pytest + frontend build)  →  5 build + Trivy image scan
     →  6 push to ACR **and** Docker Hub  →  7 cosign sign (keyless)
```

Enterprise properties:
- **Passwordless** — Azure/ACR via OIDC; **keyless** cosign signing (Sigstore/Fulcio,
  no keys to manage). Verify later with the workflow's OIDC identity.
- **Hard gates** — GitLeaks (any leak), Sonar **quality gate**, OWASP `--failOnCVSS 7`,
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
| Secret | `NVD_API_KEY` | *(optional)* speeds up OWASP DC |
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
