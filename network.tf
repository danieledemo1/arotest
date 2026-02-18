# ---------------------------------------------------------------------------
# Virtual network
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "aro" {
  name                = "aro-vnet"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
  address_space       = [var.vnet_address_space]
}

# ---------------------------------------------------------------------------
# Subnets
# ARO requires two empty subnets — one for master nodes, one for workers.
# Service endpoint for Microsoft.ContainerRegistry is recommended to allow
# the cluster to pull images without traversing the public internet.
# ---------------------------------------------------------------------------

resource "azurerm_subnet" "master" {
  name                 = "master"
  resource_group_name  = azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = [var.master_subnet_prefix]

  service_endpoints = ["Microsoft.ContainerRegistry"]

  # Private link policies must be disabled on the master subnet for ARO.
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "worker" {
  name                 = "worker"
  resource_group_name  = azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = [var.worker_subnet_prefix]

  service_endpoints = ["Microsoft.ContainerRegistry"]
}
