# -----------------------------------------------------------------------------
# Azure Key Vault (RBAC-authorized). Secrets are written by the deployer (granted
# "Key Vault Secrets Officer"); the AKS Secrets Store CSI identity is granted
# read access from the root module. RBAC (not access policies) is the modern,
# auditable model.
# -----------------------------------------------------------------------------

resource "azurerm_key_vault" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name

  # Authorize with Azure RBAC instead of legacy access policies.
  rbac_authorization_enabled = true

  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = var.public_network_access_enabled

  network_acls {
    # POC: allow, but let trusted Azure services (AKS CSI) bypass. Switch to
    # "Deny" + private endpoint for production.
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# Let the deployer manage secret values.
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.admin_object_id
}

# RBAC role assignments are eventually consistent; wait before writing secrets
# so the first apply doesn't race the permission propagation.
resource "time_sleep" "wait_for_rbac" {
  depends_on      = [azurerm_role_assignment.deployer_secrets_officer]
  create_duration = "30s"
}

resource "azurerm_key_vault_secret" "this" {
  # Secret names are not sensitive (only the values are), so iterate the keys.
  for_each = nonsensitive(toset(keys(var.secrets)))

  name         = each.value
  value        = var.secrets[each.value]
  key_vault_id = azurerm_key_vault.this.id
  tags         = var.tags

  depends_on = [time_sleep.wait_for_rbac]
}
