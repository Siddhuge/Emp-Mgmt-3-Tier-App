# -----------------------------------------------------------------------------
# AKS cluster (cost-efficient POC defaults):
#   - single system node pool (runs app workloads too)
#   - Free control-plane tier, small burstable VMs, small OS disk
#   - Azure CNI Overlay + Calico (pods don't consume VNet IPs; NetworkPolicy
#     enforcement works, unlike kind's kindnet)
#   - System-assigned managed identity, OIDC issuer + Workload Identity enabled
#   - Key Vault Secrets Provider (CSI) add-on with rotation
# -----------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # Managed cluster identity for infra operations (LB, disks, etc.).
  node_resource_group = "rg-${var.name}-nodes"

  # Modern identity: OIDC + Workload Identity for pod-level Entra federation.
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled = true

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_pool.vm_size
    vnet_subnet_id       = var.subnet_id
    orchestrator_version = var.kubernetes_version
    os_sku               = var.os_sku
    os_disk_size_gb      = var.os_disk_size_gb
    max_pods             = 110

    auto_scaling_enabled = var.node_pool.enable_auto_scaling
    node_count           = var.node_pool.node_count
    min_count            = var.node_pool.enable_auto_scaling ? var.node_pool.min_count : null
    max_count            = var.node_pool.enable_auto_scaling ? var.node_pool.max_count : null

    # Needed for in-place changes to some immutable node-pool fields.
    temporary_name_for_rotation = "systmp"

    upgrade_settings {
      max_surge = "10%"
    }

    tags = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = var.network_policy
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    pod_cidr            = var.pod_cidr
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Container Insights only when a workspace is supplied (cost control).
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id == null ? [] : [1]
    content {
      log_analytics_workspace_id      = var.log_analytics_workspace_id
      msi_auth_for_monitoring_enabled = true
    }
  }

  auto_scaler_profile {
    scale_down_unneeded = "5m"
    expander            = "least-waste"
  }

  tags = var.tags

  lifecycle {
    # The cluster autoscaler owns the live node count; ignore drift on it.
    ignore_changes = [default_node_pool[0].node_count]
  }
}
