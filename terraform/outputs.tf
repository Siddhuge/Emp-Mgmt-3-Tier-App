output "resource_group_name" {
  description = "Resource group name."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure region."
  value       = azurerm_resource_group.this.location
}

output "aks_cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.name
}

output "aks_get_credentials_command" {
  description = "Command to fetch kubeconfig for this cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${module.aks.name} --overwrite-existing"
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL (for workload identity federation)."
  value       = module.aks.oidc_issuer_url
}

output "key_vault_name" {
  description = "Key Vault name."
  value       = module.keyvault.name
}

output "key_vault_uri" {
  description = "Key Vault URI."
  value       = module.keyvault.uri
}

output "acr_login_server" {
  description = "ACR login server (null when ACR is disabled)."
  value       = var.enable_acr ? azurerm_container_registry.this[0].login_server : null
}

output "kube_config_raw" {
  description = "Raw kubeconfig (sensitive). Prefer aks_get_credentials_command."
  value       = module.aks.kube_config_raw
  sensitive   = true
}
