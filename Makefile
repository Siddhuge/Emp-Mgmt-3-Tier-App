# Employee Management — Phase 2 (production images & supply chain)
# Config is overridable: `make build REGISTRY=docker.io/you VERSION=1.2.3`

REGISTRY ?= employee-management
VERSION  ?= $(shell tr -d '[:space:]' < VERSION 2>/dev/null || echo dev)
export REGISTRY VERSION

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

## ---- Development ----
.PHONY: dev-up dev-down
dev-up: ## Start the dev stack (docker-compose.yml)
	docker compose up --build -d
dev-down: ## Stop the dev stack
	docker compose down

## ---- Production images ----
.PHONY: build scan sbom sign push release
build: ## Build hardened, versioned images for all components
	./scripts/build.sh
scan: ## Scan images for vulns + secrets (Trivy)
	./scripts/scan.sh
sbom: ## Generate SBOMs (Syft, SPDX + CycloneDX)
	./scripts/sbom.sh
sign: ## Sign pushed images (cosign)
	./scripts/sign.sh
push: ## Push versioned images to $(REGISTRY)
	./scripts/push.sh
release: ## Full pipeline: build -> scan -> sbom (-> push -> sign if PUSH=1)
	./scripts/release.sh

## ---- Validation ----
.PHONY: prod-up prod-down validate sign-demo
prod-up: ## Start the production stack (needs .env.dev or --env-file)
	docker compose --env-file .env.dev -f docker-compose.prod.yml up -d
prod-down: ## Stop the production stack
	docker compose --env-file .env.dev -f docker-compose.prod.yml down -v
validate: ## Bring up prod stack and run the Phase 2 checklist
	./scripts/validate.sh
sign-demo: ## Demo scan/SBOM/sign/verify locally via an ephemeral registry
	./scripts/local-sign-demo.sh

## ---- Phase 3: Kubernetes (Helm on kind) ----
CHART    ?= helm/employee-management
ENV      ?= dev
NAMESPACE ?= employee-$(ENV)
.PHONY: k8s-cluster k8s-deploy k8s-validate k8s-status k8s-test k8s-down
k8s-cluster: ## Create the kind cluster + ingress + metrics-server, load images
	./scripts/k8s-cluster.sh
k8s-deploy: ## Install/upgrade the chart (ENV=dev|stage|prod)
	helm upgrade --install ems $(CHART) -n $(NAMESPACE) --create-namespace \
	  -f $(CHART)/values-$(ENV).yaml --wait --timeout 240s
k8s-validate: ## Run the Phase 3 validation checklist
	NAMESPACE=$(NAMESPACE) ./scripts/k8s-validate.sh
k8s-test: ## Run the chart's helm test hook
	helm test ems -n $(NAMESPACE)
k8s-status: ## Show all workloads in the namespace
	kubectl -n $(NAMESPACE) get deploy,statefulset,svc,ingress,hpa,pdb,netpol,pods
k8s-down: ## Delete the kind cluster
	kind delete cluster --name ems

## ---- Phase 3.5: AKS via Terraform (Option B — per-env remote state) ----
TF_DIR ?= terraform
TF_ENV ?= dev
# Same storage container, distinct state object per environment.
TF_BACKEND = -backend-config=backend.hcl -backend-config=key=$(TF_ENV).tfstate
.PHONY: tf-bootstrap tf-init tf-plan tf-apply tf-destroy tf-output tf-fmt
tf-bootstrap: ## One-time: create the remote state storage + write backend.hcl
	$(TF_DIR)/scripts/bootstrap-state.sh
tf-init: ## Init backend for TF_ENV (dev|test) -> key=<env>.tfstate
	cd $(TF_DIR) && terraform init -reconfigure $(TF_BACKEND)
tf-plan: tf-init ## Plan the given TF_ENV
	cd $(TF_DIR) && terraform plan -var-file=$(TF_ENV).tfvars
tf-apply: tf-init ## Apply the given TF_ENV
	cd $(TF_DIR) && terraform apply -var-file=$(TF_ENV).tfvars
tf-destroy: tf-init ## Destroy the given TF_ENV
	cd $(TF_DIR) && terraform destroy -var-file=$(TF_ENV).tfvars
tf-output: tf-init ## Show outputs for the given TF_ENV
	cd $(TF_DIR) && terraform output
tf-fmt: ## Format all Terraform files
	cd $(TF_DIR) && terraform fmt -recursive
