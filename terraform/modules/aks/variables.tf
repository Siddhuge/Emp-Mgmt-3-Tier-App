variable "name" {
  description = "AKS cluster name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the AKS cluster."
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster API server."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. null => AKS default (recommended for POC)."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Control-plane SKU tier. Free has no SLA charge (fine for dev/test)."
  type        = string
  default     = "Free"
}

variable "subnet_id" {
  description = "Subnet ID for the node pool."
  type        = string
}

variable "node_pool" {
  description = "System node pool sizing."
  type = object({
    vm_size             = string
    node_count          = number
    min_count           = number
    max_count           = number
    enable_auto_scaling = bool
  })
}

variable "os_disk_size_gb" {
  description = "OS disk size for nodes (small = cheaper)."
  type        = number
  default     = 32
}

variable "os_sku" {
  description = "Node OS SKU (Ubuntu or AzureLinux)."
  type        = string
  default     = "Ubuntu"
}

# ---- In-cluster (overlay) networking. Independent of the VNet address space. ----
variable "service_cidr" {
  description = "CIDR for Kubernetes service IPs."
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP (must be inside service_cidr)."
  type        = string
  default     = "10.0.0.10"
}

variable "pod_cidr" {
  description = "CIDR for pod IPs (Azure CNI Overlay)."
  type        = string
  default     = "10.244.0.0/16"
}

variable "network_policy" {
  description = "Network policy engine (calico enforces the Phase 3 NetworkPolicies)."
  type        = string
  default     = "calico"
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for Container Insights. null => disabled."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the cluster."
  type        = map(string)
  default     = {}
}
