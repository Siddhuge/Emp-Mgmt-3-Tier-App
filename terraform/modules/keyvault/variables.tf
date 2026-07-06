variable "name" {
  description = "Key Vault name (globally unique, 3-24 chars, alphanumeric + hyphens)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the Key Vault."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant ID."
  type        = string
}

variable "sku_name" {
  description = "Key Vault SKU (standard is cost-efficient for a POC)."
  type        = string
  default     = "standard"
}

variable "admin_object_id" {
  description = "Object ID of the principal that manages secrets (the Terraform deployer)."
  type        = string
}

variable "secrets" {
  description = "Map of secret name => value to store in the vault."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "purge_protection_enabled" {
  description = "Enable purge protection. Off for POC so the vault can be cleaned up."
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Soft-delete retention window in days."
  type        = number
  default     = 7
}

variable "public_network_access_enabled" {
  description = "Allow public network access (POC). Use private endpoints in prod."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the Key Vault."
  type        = map(string)
  default     = {}
}
