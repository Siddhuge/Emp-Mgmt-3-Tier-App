# Remote state backend (Option B — separate state object per environment).
#
# The block is intentionally empty: all backend settings are injected at
# `terraform init` time via -backend-config, so each environment gets its own
# state object in the SAME storage container, keyed by <env>.tfstate:
#
#   Storage container "tfstate":
#     ├── dev.tfstate
#     └── test.tfstate
#
# One-time setup (creates the storage account + container, writes backend.hcl):
#   ./scripts/bootstrap-state.sh          # or: make tf-bootstrap
#
# Then init per environment (the Make targets do this for you):
#   terraform init -reconfigure -backend-config=backend.hcl -backend-config=key=dev.tfstate
#   terraform init -reconfigure -backend-config=backend.hcl -backend-config=key=test.tfstate
#
terraform {
  backend "azurerm" {}
}
