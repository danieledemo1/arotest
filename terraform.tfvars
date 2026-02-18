# ---------------------------------------------------------------------------
# Required — update before running `terraform apply`
# ---------------------------------------------------------------------------

# Short domain prefix used in DNS names and the managed resource group name.
# Only lowercase alphanumeric characters and hyphens are allowed.
domain = "myaro"

# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

location            = "eastus"
resource_group_name = "aro-rg"

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

cluster_name = "aro-cluster"
aro_version  = "4.15.35"

# Uncomment and paste your pull-secret.txt content here (as a single-line JSON string)
# to enable access to Red Hat container registries and OperatorHub.
# pull_secret = ""

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

vnet_address_space   = "10.0.0.0/22"
master_subnet_prefix = "10.0.0.0/23"
worker_subnet_prefix = "10.0.2.0/23"
pod_cidr             = "10.128.0.0/14"
service_cidr         = "172.30.0.0/16"

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

master_vm_size      = "Standard_D8s_v3"
worker_vm_size      = "Standard_D4s_v3"
worker_count        = 3
worker_disk_size_gb = 128

# ---------------------------------------------------------------------------
# Visibility — public cluster
# ---------------------------------------------------------------------------

api_server_visibility = "Public"
ingress_visibility    = "Public"

# ---------------------------------------------------------------------------
# Optional hardening (disabled by default)
# ---------------------------------------------------------------------------

fips_validated_modules    = "Disabled"
master_encryption_at_host = "Disabled"
worker_encryption_at_host = "Disabled"
