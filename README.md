# Employee Management System — 3-Tier App

A full-stack employee management app taken from local Docker to a hardened,
HTTPS, secret-free deployment on **Azure Kubernetes Service** — built the way a
real team would, in phases:

| Phase | What |
| --- | --- |
| **1** | React SPA + FastAPI + PostgreSQL, layered architecture, JWT/RBAC, Docker Compose |
| **2** | Hardened multi-stage OCI images, Trivy scan, SBOM, cosign signing |
| **3** | Production Helm chart (HPA, PDB, NetworkPolicies, Ingress, probes) |
| **3.5** | Terraform for AKS dev/test (VNet, AKS, Key Vault, ACR) + GitHub Actions CI/CD |
| **secrets** | Azure Key Vault via Secrets Store CSI + **Workload Identity** — no hardcoded secrets |
| **deploy** | Same app as **Helm**, **plain manifests**, and **Kustomize** |

The core app is a React SPA talking to a FastAPI backend over REST, with
SQLAlchemy over PostgreSQL.

```
        React Frontend  (TypeScript, MUI, React Query)
              │
        REST API (HTTP, JWT auth)
              │
        FastAPI Backend  (layered architecture)
              │
        SQLAlchemy ORM
              │
        PostgreSQL 16
```

## Project structure

```
employee-management/
├── frontend/            # React 19 + TypeScript + Vite + MUI
├── backend/             # FastAPI (layered: routes → services → repository → models)
├── database/            # PostgreSQL init script
├── helm/                # production Helm chart (source of truth for k8s)
├── k8s/                 # plain manifests + Kustomize (generated from the chart)
├── terraform/           # AKS dev/test infra (modules + per-env remote state)
├── manifests/           # cluster-scoped extras (cert-manager issuers, CoreDNS)
├── .github/workflows/   # GitHub Actions CI/CD (OIDC → Azure)
├── scripts/             # build/scan/sbom/sign, k8s, terraform bootstrap, gen-manifests
├── docker-compose.yml   docker-compose.prod.yml
└── README.md
```

## Tech stack

**Frontend:** React 19, TypeScript, Vite, Material UI, Axios, React Router, React Query
**Backend:** FastAPI, SQLAlchemy 2, Alembic, Pydantic v2, Uvicorn, JWT (python-jose), bcrypt (passlib)
**Database:** PostgreSQL 16

## Quick start (Docker — recommended)

Everything runs in containers. From the project root:

```bash
docker compose up --build
```

Then open:

| Service            | URL                          |
| ------------------ | ---------------------------- |
| Frontend (app)     | http://localhost:8080        |
| Backend API        | http://localhost:8000/api    |
| API docs (Swagger) | http://localhost:8000/docs   |
| PostgreSQL         | localhost:5432               |

The backend creates the schema and seeds demo data on first startup. The
frontend is served by nginx, which reverse-proxies `/api` to the backend
(so there are no CORS issues in the browser).

Stop with `docker compose down` (add `-v` to also wipe the database volume).

### Demo accounts

| Username   | Password      | Role     |
| ---------- | ------------- | -------- |
| `admin`    | `admin123`    | Admin    |
| `manager`  | `manager123`  | Manager  |
| `employee` | `employee123` | Employee |

**Role permissions**

| Action                             | Admin | Manager | Employee |
| ---------------------------------- | :---: | :-----: | :------: |
| View employees / depts / dashboard |  ✅   |   ✅    |    ✅    |
| Add / edit employee                |  ✅   |   ✅    |    ❌    |
| Delete employee                    |  ✅   |   ❌    |    ❌    |
| Add department                     |  ✅   |   ✅    |    ❌    |

## API endpoints

| Method | Path                  | Description                | Min role |
| ------ | --------------------- | -------------------------- | -------- |
| POST   | `/api/login`          | Obtain JWT                 | public   |
| POST   | `/api/logout`         | Logout (client-side)       | any      |
| GET    | `/api/me`             | Current user               | any      |
| GET    | `/api/employees`      | List / search (`?search=`) | any      |
| POST   | `/api/employees`      | Create employee            | manager  |
| PUT    | `/api/employees/{id}` | Update employee            | manager  |
| DELETE | `/api/employees/{id}` | Delete employee            | admin    |
| GET    | `/api/departments`    | List departments           | any      |
| POST   | `/api/departments`    | Create department          | manager  |
| GET    | `/api/dashboard`      | Aggregate stats            | any      |

## Database schema

- **users** — `id, username, password_hash, role, created_at`
- **departments** — `id, name, manager`
- **employees** — `id, first_name, last_name, email, designation, salary, is_active, department_id, created_at`
- **projects** — `id, name, is_active`

> Notes: `employees.is_active` powers the "Active Employees" dashboard metric,
> and a small `projects` table backs the "Projects" metric — both required by
> the dashboard beyond the base schema.

## Running components individually (local dev)

You don't need this if you use Docker, but for iterating on one piece:

**Backend**
```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# Point at a running Postgres, e.g.:
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/employee_db
uvicorn app.main:app --reload
```

**Frontend** (Vite dev server proxies `/api` to `http://localhost:8000`)
```bash
cd frontend
npm install
npm run dev        # http://localhost:5173
```

## Testing

Backend tests use an isolated in-memory SQLite database (no Postgres needed):

```bash
cd backend
source .venv/bin/activate
pytest              # 15 tests: auth, employees CRUD + search, RBAC, dashboard
```

Frontend type-check + production build:

```bash
cd frontend
npm run build
```

## Migrations (Alembic)

The backend uses `create_all` on startup for a frictionless local run, and
Alembic is set up as the source of truth for schema evolution:

```bash
cd backend
alembic current                       # show applied revision
alembic revision --autogenerate -m "add X"
alembic upgrade head
```

## Architecture notes

The backend follows a **layered architecture** so business logic, data access
and transport stay separate:

```
routes/          HTTP layer — request/response, status codes, auth guards
  └─ services/     business logic & validation (uniqueness, permissions)
       └─ repository/  data access — all SQLAlchemy queries live here
            └─ models/      ORM entities
schemas/         Pydantic request/response contracts
auth/            password hashing, JWT, role dependencies
```

The frontend mirrors this separation: `api/` (HTTP), `hooks/` (React Query
data layer), `context/` (auth state), `pages/` + `components/` + `layouts/`
(UI), and `routes/` (routing + protected routes).

---

# Phase 2 — Production-grade OCI images & supply chain

Phase 2 turns the app into **secure, optimized, registry-ready container
images** following enterprise/DevSecOps standards, validated locally before any
move to Kubernetes.

```
Source ─▶ Multi-stage build ─▶ Vulnerability scan ─▶ SBOM ─▶ Sign ─▶ Registry
                    (hardened, non-root, minimal)         (Trivy)  (Syft) (cosign)
```

## What Phase 2 adds

| Concern                 | Implementation |
| ----------------------- | -------------- |
| Multi-stage builds      | `backend/Dockerfile` (venv builder → slim runtime), `frontend/Dockerfile` (Node build → nginx serve) |
| Minimal base images     | `python:3.12-slim`, `nginxinc/nginx-unprivileged:1.27-alpine` (no Node in prod) |
| Non-root containers     | backend `appuser` (UID 10001), frontend nginx (UID 101) |
| Health checks           | backend `GET /health` (stdlib probe), frontend `GET /healthz` |
| Image optimization      | `.dockerignore`, no test deps/pip/build tools in runtime, split `requirements*.txt` |
| Config externalization  | `.env.example` + `.env.dev/.stage/.prod`, `LOG_LEVEL`, no baked secrets |
| Hardened runtime        | `read_only` rootfs, `cap_drop: ALL`, `no-new-privileges`, tmpfs, resource limits |
| Dependency-aware startup| db *healthy* → backend *healthy* → frontend |
| Vulnerability scanning  | Trivy (OS + libs + secrets), gate fails on fixable CRITICAL |
| SBOM                    | Syft, SPDX **and** CycloneDX JSON per image |
| Image signing           | cosign (key-pair), signatures verified by digest |
| Version tagging         | immutable `:vX.Y.Z` + `:git-<ref>`, never `:latest` |

## Image tagging strategy

`VERSION` (from the `VERSION` file) drives immutable tags; every build also
emits a `git-<ref>` tag for traceability. `latest` is never used.

```
<REGISTRY>/backend:1.0.0        <REGISTRY>/backend:git-9c82ab3
<REGISTRY>/frontend:1.0.0       <REGISTRY>/frontend:git-9c82ab3
<REGISTRY>/database-init:1.0.0  <REGISTRY>/database-init:git-9c82ab3
```

## Build, scan, SBOM, sign — the scripts

All wrapped by the `Makefile` (`make help`) and driven by `REGISTRY` / `VERSION`:

```bash
make build                       # scripts/build.sh  — hardened, versioned images
make scan                        # scripts/scan.sh   — Trivy vuln+secret gate → reports/
make sbom                        # scripts/sbom.sh   — Syft SPDX+CycloneDX → sbom/
make sign                        # scripts/sign.sh   — cosign sign (pushed images)
make push                        # scripts/push.sh   — push version + git tags
make release                     # build → scan → sbom  (+ push+sign when PUSH=1)

# Full publish to a real registry:
REGISTRY=docker.io/you VERSION=1.0.0 PUSH=1 make release
```

Supported registries (set `REGISTRY`): Docker Hub (`docker.io/you`),
ACR (`*.azurecr.io`), ECR (`*.dkr.ecr.*.amazonaws.com`), or any OCI registry.

## Running the production stack locally

```bash
docker compose --env-file .env.dev -f docker-compose.prod.yml up -d --build
# app: http://localhost:8080   api: http://localhost:8000/api
docker compose --env-file .env.dev -f docker-compose.prod.yml down -v
```

`.env.prod`/`.env.stage` require real secrets (`JWT_SECRET`,
`SEED_ADMIN_PASSWORD`, DB password) — the compose file refuses to start without
them.

## Validation (the Phase 2 checklist, automated)

```bash
make validate      # scripts/validate.sh
```

Brings up the production stack and asserts, then tears it down. Verified run:

```
✔ Frontend loads (GET /)                 ✔ Backend runs as non-root
✔ Frontend health (GET /healthz)         ✔ Frontend runs as non-root
✔ Backend health (GET /health)           ✔ Backend filesystem is read-only
✔ Backend API reachable (login)          ✔ Frontend filesystem is read-only
✔ DB reachable + seeded                  ✔ no-new-privileges on backend
✔ All capabilities dropped (backend)     ✔ Config externalized (no source mount)
→ 12 passed, 0 failed
```

Signing/verification is proven locally with no external registry via
`make sign-demo` (spins up an ephemeral `registry:2`, pushes, signs by digest,
verifies, cleans up).

## Image results

| Image           | Base                          | User        | Size   |
| --------------- | ----------------------------- | ----------- | ------ |
| `backend`       | python:3.12-slim              | appuser     | ~230MB |
| `frontend`      | nginx-unprivileged:1.27-alpine| nginx (101) | ~60MB  |
| `database-init` | postgres:16-alpine            | postgres    | ~294MB |

**Scan gate:** no fixable CRITICAL vulnerabilities. Remediations applied:
`python-jose` 3.3.0 → 3.4.0 (CVE-2024-33663) and `apk upgrade` on the frontend
base (CVE-2026-31789). One base-image CVE that can't be rebuilt locally (`gosu`
in the postgres image) is documented and accepted in `.trivyignore`.

## Security hardening summary

- Non-root users, `read_only` root filesystem with tmpfs for writable paths
- `cap_drop: ALL`, `security_opt: no-new-privileges`
- Minimal images: no build toolchain, no test deps, no Node runtime in prod
- Pinned dependency and base-image versions; immutable image tags
- No secrets in images — all config via environment / secret manager
- Logs to stdout/stderr (json-file driver with rotation) for K8s/Docker collectors
- Images scanned, SBOM'd, and signed before publishing

---

# Phase 3 — Kubernetes deployment (Helm, enterprise-grade)

Phase 3 deploys the Phase 2 images to Kubernetes via a **production-grade Helm
chart** with scaling, self-healing, rolling updates, persistent storage, secure
config, and production networking. Validated end-to-end on a local multi-node
**kind** cluster.

```
Internet ─▶ NGINX Ingress ─┬─ /   ─▶ Frontend Service ─▶ React pods (HPA 3–10)
                           └─ /api ─▶ Backend Service  ─▶ FastAPI pods (HPA 3–10)
                                                             │
                                              Postgres Service (headless)
                                                             │
                                          PostgreSQL StatefulSet ─▶ PVC
```

## The chart

`helm/employee-management/` — one reusable chart, per-environment values:

```
Chart.yaml   values.yaml   values-dev.yaml   values-stage.yaml   values-prod.yaml
templates/
  _helpers.tpl              configmap.yaml            secret.yaml
  serviceaccount.yaml       role.yaml                 rolebinding.yaml
  backend-deployment.yaml   backend-service.yaml
  frontend-deployment.yaml  frontend-service.yaml     frontend-configmap.yaml
  postgres-statefulset.yaml postgres-service.yaml     pvc.yaml
  ingress.yaml   hpa.yaml   pdb.yaml   networkpolicy.yaml   NOTES.txt
  tests/test-connection.yaml
```

| Concern              | Implementation |
| -------------------- | -------------- |
| Deployments          | frontend + backend, 3 replicas, `RollingUpdate` (maxSurge 1 / maxUnavailable 0) |
| Database             | StatefulSet + `volumeClaimTemplates` PVC, headless Service, stable identity |
| Health probes        | startup + readiness + liveness (HTTP for apps, `pg_isready` for DB) |
| Config / secrets     | ConfigMap (non-secret) + Secret (`DATABASE_URL`, `JWT_SECRET`, …) via `envFrom` |
| Autoscaling          | HPA v2, CPU 70% / memory 75%, min 3 → max 10 |
| Availability         | PodDisruptionBudget `minAvailable: 2`; pod anti-affinity (soft dev / hard prod) |
| Networking           | Ingress (path routing `/`→FE, `/api`→BE, TLS in stage/prod) |
| Network policy       | default-deny + explicit allows (ingress→FE, FE/ingress→BE, BE→DB, DNS) |
| Security             | non-root, read-only rootfs, `cap_drop: ALL`, seccomp RuntimeDefault, RBAC, no token automount |
| Graceful shutdown    | `terminationGracePeriodSeconds` + preStop drain |
| Config-change rollout| `checksum/config` + `checksum/secret` pod annotations |

## Environments & namespaces

Same chart, three value files → three namespaces:

```bash
helm upgrade --install ems helm/employee-management -n employee-dev   --create-namespace -f helm/employee-management/values-dev.yaml
helm upgrade --install ems helm/employee-management -n employee-stage --create-namespace -f helm/employee-management/values-stage.yaml
helm upgrade --install ems helm/employee-management -n employee-prod  --create-namespace -f helm/employee-management/values-prod.yaml
```

- **dev** — smaller resources/replicas (fits a laptop), soft anti-affinity, no TLS.
- **stage** — 3 replicas, TLS via cert-manager, `ssl-redirect`.
- **prod** — hard anti-affinity, TLS + force-ssl-redirect, `secrets.create=false`
  (bring your own Secret via a secret store / sealed-secrets).

## Try it locally on kind (fully reproducible)

```bash
make k8s-cluster     # 3-node kind cluster + ingress-nginx + metrics-server + load images
make k8s-deploy      # helm upgrade --install (ENV=dev by default)
make k8s-validate    # runs the Phase 3 checklist (14 checks)
make k8s-status      # show all workloads
make k8s-test        # helm test hook (in-cluster health checks)
make k8s-down        # delete the cluster
```

Reaching the app on kind (ingress controller runs on a worker, so port-forward
is the reliable path):

```bash
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8090:80 &
curl -H "Host: employee.dev.sidhuge.xyz" http://localhost:8090/            # UI
curl -H "Host: employee.dev.sidhuge.xyz" http://localhost:8090/api/dashboard
```

## Validation results (run on a live 3-node kind cluster)

```
✔ Frontend accessible via Ingress        ✔ NetworkPolicies present (>=5)
✔ Frontend health via Ingress            ✔ ConfigMap mounted (LOG_LEVEL in pod)
✔ Backend API responds (login)           ✔ Secret mounted (DATABASE_URL in pod)
✔ Backend->DB works (dashboard)          ✔ Backend runs as non-root
✔ Postgres StatefulSet ready             ✔ Resource requests+limits set
✔ Postgres PVC bound                     ✔ Replicas spread across nodes
✔ Backend HPA present + reading metrics  → 14 passed, 0 failed
✔ PDBs present (backend+frontend)
```

Additionally demonstrated live:
- **Data persistence** — created a record, deleted `postgres-0`; StatefulSet
  recreated the pod and the record survived via the PVC.
- **Zero-downtime rolling update** — `rollout restart` of the backend under
  continuous load: **300/300 requests succeeded, 0 failures**.
- **HPA autoscaling** — bcrypt-heavy login load drove backend CPU to ~500% of
  target; HPA scaled **2 → 5** pods, then back down after load.
- **helm test** hook (`TEST SUITE … Phase: Succeeded`).

> **Network policy note:** the policies are authored to enforce
> ingress→frontend→backend→postgres and default-deny. kind's default CNI
> (kindnet) creates but does **not enforce** NetworkPolicy; enforcement requires
> a policy-capable CNI (Calico/Cilium) or a managed cluster (AKS/EKS/GKE) that
> supports it. The objects are validated as correct and present.

---

# Phase 3.5 — AKS on Azure (Terraform + CI/CD)

Cost-efficient, enterprise-shaped AKS **dev** and **test** environments, all as
code. Full detail in [terraform/README.md](terraform/README.md).

- **Modules:** VNet + NSG, AKS (Azure CNI Overlay + Calico, OIDC + Workload
  Identity, KV CSI add-on), RBAC Key Vault (+ generated secrets), Basic ACR.
- **Cost knobs only** differ dev↔test (VM size, autoscaler, monitoring).
- **Remote state per environment** (Option B): one state object per env in Azure
  Storage; `make tf-bootstrap` then `make tf-plan TF_ENV=dev`.

```bash
make tf-bootstrap                     # one-time: state backend
make tf-plan  TF_ENV=dev              # fmt → tflint → plan
make tf-apply TF_ENV=dev              # create AKS/KV/ACR/…
terraform output -raw aks_get_credentials_command | bash
```

## CI/CD — GitHub Actions (passwordless)

`.github/workflows/` — Terraform pipeline using **OIDC** (no stored secrets):

- **PR →** `fmt` → `tflint` → Trivy IaC scan → `validate` → **plan** (dev+test),
  posted as PR comments.
- **merge to main →** **apply** dev → then test, each behind a GitHub Environment
  approval gate. Manual dispatch + guarded destroy included.

Setup (one-time OIDC federation, roles, variables) is in
[.github/workflows/README.md](.github/workflows/README.md).

## Secrets — Key Vault + Workload Identity (no hardcoded secrets)

Nothing sensitive lives in Git, images, or values files. On AKS:

```
Key Vault (jwt-secret, postgres-password, seed-admin-password)
   │  Workload Identity: UAMI federated to the app ServiceAccount (Terraform)
   ▼
Secrets Store CSI driver → synced K8s Secret → pods (DATABASE_URL assembled in-pod)
```

The Helm chart ships a `SecretProviderClass` and wires the ServiceAccount
annotation + pod labels; `terraform output helm_keyvault_set_flags` prints the
`--set keyVault.*` values. Local kind uses generated (uncommitted) secrets.

## Deployment options — Helm · plain manifests · Kustomize

The same app deploys three ways (Helm is the source of truth; the others are
generated from it via `make k8s-manifests`). See [k8s/README.md](k8s/README.md).

```bash
# Helm
helm upgrade --install ems helm/employee-management -n employee-dev --create-namespace \
  -f helm/employee-management/values-dev.yaml \
  --set image.registry=$ACR $(terraform output -raw helm_keyvault_set_flags)

# Kustomize (per-env overlays: dev / stage / prod)
kubectl kustomize k8s/kustomize/overlays/dev \
  | envsubst '${REGISTRY} ${KV_NAME} ${KV_TENANT_ID} ${KV_CLIENT_ID}' | kubectl apply -f -
```

## Live proof

Deployed to a real AKS dev cluster and served at **https://employee.dev.sidhuge.xyz**
with a trusted Let's Encrypt certificate (cert-manager), images pulled from ACR,
secrets from Key Vault, HPA/PDB/NetworkPolicies enforced (Calico) — then torn
down with `terraform destroy`. The full walkthrough lives across the phase docs.
