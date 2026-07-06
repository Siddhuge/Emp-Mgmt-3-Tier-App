# Authentication: run `az login` first (or use a service principal / OIDC in CI).
# subscription_id defaults to the ARM_SUBSCRIPTION_ID env var when var is null.
provider "azurerm" {
  features {
    key_vault {
      # POC-friendly: allow vaults to be deleted/purged during teardown.
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}
