# ---- Dev environment (smallest / cheapest) ----
environment = "dev"
location    = "eastus"

vnet_address_space = ["10.10.0.0/16"]
aks_subnet_prefix  = ["10.10.1.0/24"]

kubernetes_version = null # use AKS default
aks_sku_tier       = "Free"

# Single small burstable node, no autoscaling.
node_pool = {
  vm_size             = "Standard_B2s" # 2 vCPU / 4 GiB (burstable, cheapest)
  node_count          = 1
  min_count           = 1
  max_count           = 1
  enable_auto_scaling = false
}

# Keep costs minimal: no Container Insights in dev.
enable_monitoring = false

enable_acr = true
acr_sku    = "Basic"
