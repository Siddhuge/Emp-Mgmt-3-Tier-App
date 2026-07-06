variable "name_prefix" {
  description = "Prefix used to name network resources (e.g. emp-dev)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to create the network in."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
}

variable "aks_subnet_prefix" {
  description = "Address prefix(es) for the AKS node subnet."
  type        = list(string)
}

variable "ingress_allowed_ports" {
  description = "Inbound TCP ports to allow to the ingress LoadBalancer. Empty disables the rule."
  type        = list(string)
  default     = ["80", "443"]
}

variable "ingress_source" {
  description = "Source address prefix allowed to reach the ingress (Internet, a CIDR, or a service tag)."
  type        = string
  default     = "Internet"
}

variable "tags" {
  description = "Tags applied to all network resources."
  type        = map(string)
  default     = {}
}
