# ---------------------------------------------------------------------------
# ARO requires nine user-assigned managed identities:
#
#   aro-cluster            — cluster identity; used to federate credentials
#                            for the eight operator identities below.
#   cloud-controller-manager
#   ingress
#   machine-api
#   disk-csi-driver
#   cloud-network-config
#   image-registry
#   file-csi-driver
#   aro-operator
#
# Reference:
#   https://learn.microsoft.com/azure/openshift/howto-understand-managed-identities
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "cluster" {
  name                = "aro-cluster"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}

resource "azurerm_user_assigned_identity" "cloud_controller_manager" {
  name                = "cloud-controller-manager"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}

resource "azurerm_user_assigned_identity" "ingress" {
  name                = "ingress"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}

resource "azurerm_user_assigned_identity" "machine_api" {
  name                = "machine-api"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}

resource "azurerm_user_assigned_identity" "disk_csi_driver" {
  name                = "disk-csi-driver"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}

resource "azurerm_user_assigned_identity" "cloud_network_config" {
  name                = "cloud-network-config"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}

resource "azurerm_user_assigned_identity" "image_registry" {
  name                = "image-registry"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}

resource "azurerm_user_assigned_identity" "file_csi_driver" {
  name                = "file-csi-driver"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}

resource "azurerm_user_assigned_identity" "aro_operator" {
  name                = "aro-operator"
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}
