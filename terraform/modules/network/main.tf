# -----------------------------------------------------------------------------
# Network: one VNet with a dedicated subnet for the AKS node pool, guarded by an
# NSG. Azure CNI Overlay is used by AKS, so pod IPs do NOT consume subnet space
# (cost/efficiency win) — a small /24 comfortably hosts the nodes.
# -----------------------------------------------------------------------------

resource "azurerm_network_security_group" "aks" {
  name                = "nsg-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # When you bring your own subnet NSG, the AKS cloud-controller only adds
  # LoadBalancer rules to the node NSG it manages — NOT here. The subnet NSG is
  # evaluated first, so we must explicitly allow the ingress ports, otherwise
  # inbound HTTP/HTTPS to the ingress LoadBalancer is dropped.
  dynamic "security_rule" {
    for_each = length(var.ingress_allowed_ports) > 0 ? [1] : []
    content {
      name                       = "allow-web-inbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = var.ingress_allowed_ports
      source_address_prefix      = var.ingress_source
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.aks_subnet_prefix
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}
