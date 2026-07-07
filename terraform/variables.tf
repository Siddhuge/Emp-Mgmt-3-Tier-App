# ---- Provider / subscription ----
variable "subscription_id" {
  description = "Azure subscription ID. If null, ARM_SUBSCRIPTION_ID env var is used."
  type        = string
  default     = null
}

# ---- Environment ----
variable "environment" {
  description = "Environment name (dev or test)."
  type        = string
  validation {
    condition     = contains(["dev", "test"], var.environment)
    error_message = "environment must be either 'dev' or 'test'."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Extra tags merged into the default tag set."
  type        = map(string)
  default     = {}
}

# ---- Networking ----
variable "vnet_address_space" {
  description = "VNet address space."
  type        = list(string)
}

variable "aks_subnet_prefix" {
  description = "AKS node subnet prefix."
  type        = list(string)
}

# ---- AKS ----
variable "kubernetes_version" {
  description = "Kubernetes version. null => AKS default."
  type        = string
  default     = null
}

variable "aks_sku_tier" {
  description = "AKS control-plane SKU tier (Free or Standard)."
  type        = string
  default     = "Free"
}

variable "node_pool" {
  description = "System node pool sizing (the main dev/test cost lever)."
  type = object({
    vm_size             = string
    node_count          = number
    min_count           = number
    max_count           = number
    enable_auto_scaling = bool
  })
}

# ---- Add-ons / cost toggles ----
variable "enable_monitoring" {
  description = "Deploy Log Analytics + Container Insights (adds cost)."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log Analytics retention (days). Minimum 30."
  type        = number
  default     = 30
}

variable "enable_acr" {
  description = "Deploy an Azure Container Registry and attach it to AKS."
  type        = bool
  default     = true
}

variable "acr_sku" {
  description = "ACR SKU (Basic is cheapest)."
  type        = string
  default     = "Basic"
}

# ---- Workload identity (Key Vault access for the app) ----
variable "app_namespace" {
  description = "Kubernetes namespace the app runs in. Empty => employee-<environment>."
  type        = string
  default     = ""
}

variable "app_service_account" {
  description = "Kubernetes ServiceAccount name the app pods use (matches the Helm release: <release>-employee-management)."
  type        = string
  default     = "ems-employee-management"
}

# ---- Application secrets ----
variable "seed_admin_password" {
  description = "Seed admin password stored in Key Vault. null => auto-generated."
  type        = string
  default     = null
  sensitive   = true
}
