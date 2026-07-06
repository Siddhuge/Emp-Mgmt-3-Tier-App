# ---- Test environment (slightly larger; validates scaling + monitoring) ----
environment = "test"
location    = "eastus"

vnet_address_space = ["10.20.0.0/16"]
aks_subnet_prefix  = ["10.20.1.0/24"]

kubernetes_version = null
aks_sku_tier       = "Free"

# Slightly bigger node + cluster autoscaler (1..3) to exercise HPA/scaling.
node_pool = {
  vm_size             = "Standard_B2ms" # 2 vCPU / 8 GiB (more memory headroom)
  node_count          = 1
  min_count           = 1
  max_count           = 3
  enable_auto_scaling = true
}

# Turn on Container Insights in test to validate observability.
enable_monitoring  = true
log_retention_days = 30

enable_acr = true
acr_sku    = "Basic"
