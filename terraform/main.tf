# =============================================================================
# Root module — composes network + Key Vault + AKS (+ optional ACR & monitoring)
# for a single environment (dev or test). Use one Terraform workspace per
# environment so state stays isolated; see terraform/README.md.
# =============================================================================

data "azurerm_client_config" "current" {}

# Short random suffix for globally-unique names (Key Vault, ACR).
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
  numeric = true
}

# Application secrets are generated here (never hardcoded) and pushed to Key Vault.
resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

resource "random_password" "postgres_password" {
  length  = 24
  special = false
}

resource "random_password" "seed_admin" {
  count   = var.seed_admin_password == null ? 1 : 0
  length  = 16
  special = false
}

locals {
  name_prefix = "emp-${var.environment}"

  common_tags = merge({
    project     = "employee-management"
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "poc"
  }, var.tags)

  seed_admin_password = coalesce(var.seed_admin_password, try(random_password.seed_admin[0].result, null))

  # Namespace the app is deployed into (defaults to employee-<env> to match Helm).
  app_namespace = coalesce(var.app_namespace, "employee-${var.environment}")

  # Secret names match what the Helm chart / app expect.
  key_vault_secrets = {
    "jwt-secret"          = random_password.jwt_secret.result
    "postgres-password"   = random_password.postgres_password.result
    "seed-admin-password" = local.seed_admin_password
  }
}

# ---- Resource group ----
resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

# ---- Optional: Log Analytics (Container Insights) ----
resource "azurerm_log_analytics_workspace" "this" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "log-${local.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.common_tags
}

# ---- Optional: Azure Container Registry (hosts the Phase 2 images) ----
resource "azurerm_container_registry" "this" {
  count                         = var.enable_acr ? 1 : 0
  name                          = "acremp${var.environment}${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  sku                           = var.acr_sku
  admin_enabled                 = false
  public_network_access_enabled = true
  tags                          = local.common_tags
}

# ---- Network ----
module "network" {
  source              = "./modules/network"
  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  vnet_address_space  = var.vnet_address_space
  aks_subnet_prefix   = var.aks_subnet_prefix
  tags                = local.common_tags
}

# ---- Key Vault (+ secrets) ----
module "keyvault" {
  source              = "./modules/keyvault"
  name                = "kv-emp-${var.environment}-${random_string.suffix.result}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  admin_object_id     = data.azurerm_client_config.current.object_id
  secrets             = local.key_vault_secrets
  tags                = local.common_tags
}

# ---- AKS ----
module "aks" {
  source              = "./modules/aks"
  name                = "aks-${local.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "aks-${local.name_prefix}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.aks_sku_tier
  subnet_id           = module.network.aks_subnet_id
  node_pool           = var.node_pool

  log_analytics_workspace_id = var.enable_monitoring ? azurerm_log_analytics_workspace.this[0].id : null
  tags                       = local.common_tags
}

# ---- Workload Identity for Key Vault access ----
# Dedicated user-assigned identity, federated to the app's Kubernetes
# ServiceAccount via the AKS OIDC issuer. Pods get Key Vault access without any
# node-wide identity or stored credentials (least privilege).
resource "azurerm_user_assigned_identity" "kv" {
  name                = "id-${local.name_prefix}-kv"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.common_tags
}

resource "azurerm_federated_identity_credential" "kv" {
  name                = "fic-${local.name_prefix}-kv"
  resource_group_name = azurerm_resource_group.this.name
  parent_id           = azurerm_user_assigned_identity.kv.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  # Trust only this namespace + ServiceAccount (matches the Helm release).
  subject = "system:serviceaccount:${local.app_namespace}:${var.app_service_account}"
}

# ---- Role assignments ----
# The workload-identity UAMI -> read secrets from Key Vault.
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.kv.principal_id
}

# AKS kubelet identity -> pull images from ACR.
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.enable_acr ? 1 : 0
  scope                = azurerm_container_registry.this[0].id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity_object_id
}
