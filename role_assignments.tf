# ---------------------------------------------------------------------------
# Local helpers: build subscription-scoped role definition IDs
#
# Role UUIDs sourced from the official Microsoft documentation:
# https://learn.microsoft.com/azure/openshift/howto-create-openshift-cluster
# ---------------------------------------------------------------------------

locals {
  sub_id = data.azurerm_client_config.current.subscription_id

  # Built-in role definition IDs used by ARO managed-identity deployment.
  role = {
    # Grants the cluster identity the ability to federate credentials for
    # each operator identity (assigned on every operator MSI resource).
    managed_identity_operator = "/subscriptions/${local.sub_id}/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e"

    # cloud-controller-manager → master & worker subnets
    # (Azure Red Hat OpenShift Cloud Controller Manager role)
    ccm_subnet = "/subscriptions/${local.sub_id}/providers/Microsoft.Authorization/roleDefinitions/a1f96423-95ce-4224-ab27-4e3dc72facd4"

    # ingress → master & worker subnets
    # (Azure Red Hat OpenShift Ingress Operator role)
    ingress_subnet = "/subscriptions/${local.sub_id}/providers/Microsoft.Authorization/roleDefinitions/0336e1d3-7a87-462b-b6db-342b63f7802c"

    # machine-api → master & worker subnets
    # (Azure Red Hat OpenShift Machine API Operator role)
    machine_api_subnet = "/subscriptions/${local.sub_id}/providers/Microsoft.Authorization/roleDefinitions/0358943c-7e01-48ba-8889-02cc51d78637"

    # cloud-network-config → vnet
    # (Azure Red Hat OpenShift Network Operator role)
    cloud_network_vnet = "/subscriptions/${local.sub_id}/providers/Microsoft.Authorization/roleDefinitions/be7a6435-15ae-4171-8f30-4a343eff9e8f"

    # file-csi-driver → vnet
    # (Azure Red Hat OpenShift File CSI Driver Operator role)
    file_csi_vnet = "/subscriptions/${local.sub_id}/providers/Microsoft.Authorization/roleDefinitions/0d7aedc0-15fd-4a67-a412-efad370c947e"

    # image-registry → vnet
    # (Azure Red Hat OpenShift Image Registry Operator role)
    image_registry_vnet = "/subscriptions/${local.sub_id}/providers/Microsoft.Authorization/roleDefinitions/8b32b316-c2f5-4ddf-b05b-83dacd2d08b5"

    # aro-operator → master & worker subnets
    # (Azure Red Hat OpenShift ARO Operator role)
    aro_operator_subnet = "/subscriptions/${local.sub_id}/providers/Microsoft.Authorization/roleDefinitions/4436bae4-7702-4c84-919b-c4069ff25ee2"

    # ARO RP first-party SP → vnet  (Contributor-equivalent on networking)
    aro_rp_vnet = "/subscriptions/${local.sub_id}/providers/Microsoft.Authorization/roleDefinitions/42f3c60f-e7b1-46d7-ba56-6de681664342"
  }
}

# ===========================================================================
# Section 1 — Cluster identity → operator identities
#
# The cluster identity (aro-cluster) needs Managed Identity Operator on each
# of the eight operator identities so it can federate their credentials.
# ===========================================================================

resource "azurerm_role_assignment" "cluster_to_ccm" {
  scope              = azurerm_user_assigned_identity.cloud_controller_manager.id
  role_definition_id = local.role.managed_identity_operator
  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cluster_to_ingress" {
  scope              = azurerm_user_assigned_identity.ingress.id
  role_definition_id = local.role.managed_identity_operator
  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cluster_to_machine_api" {
  scope              = azurerm_user_assigned_identity.machine_api.id
  role_definition_id = local.role.managed_identity_operator
  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cluster_to_disk_csi_driver" {
  scope              = azurerm_user_assigned_identity.disk_csi_driver.id
  role_definition_id = local.role.managed_identity_operator
  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cluster_to_cloud_network_config" {
  scope              = azurerm_user_assigned_identity.cloud_network_config.id
  role_definition_id = local.role.managed_identity_operator
  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cluster_to_image_registry" {
  scope              = azurerm_user_assigned_identity.image_registry.id
  role_definition_id = local.role.managed_identity_operator
  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cluster_to_file_csi_driver" {
  scope              = azurerm_user_assigned_identity.file_csi_driver.id
  role_definition_id = local.role.managed_identity_operator
  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cluster_to_aro_operator" {
  scope              = azurerm_user_assigned_identity.aro_operator.id
  role_definition_id = local.role.managed_identity_operator
  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  principal_type     = "ServicePrincipal"
}

# ===========================================================================
# Section 2 — Operator identities → subnets
# ===========================================================================

# cloud-controller-manager — Network Contributor on master and worker subnets
resource "azurerm_role_assignment" "ccm_master_subnet" {
  scope              = azurerm_subnet.master.id
  role_definition_id = local.role.ccm_subnet
  principal_id       = azurerm_user_assigned_identity.cloud_controller_manager.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "ccm_worker_subnet" {
  scope              = azurerm_subnet.worker.id
  role_definition_id = local.role.ccm_subnet
  principal_id       = azurerm_user_assigned_identity.cloud_controller_manager.principal_id
  principal_type     = "ServicePrincipal"
}

# ingress — Ingress Operator role on master and worker subnets
resource "azurerm_role_assignment" "ingress_master_subnet" {
  scope              = azurerm_subnet.master.id
  role_definition_id = local.role.ingress_subnet
  principal_id       = azurerm_user_assigned_identity.ingress.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "ingress_worker_subnet" {
  scope              = azurerm_subnet.worker.id
  role_definition_id = local.role.ingress_subnet
  principal_id       = azurerm_user_assigned_identity.ingress.principal_id
  principal_type     = "ServicePrincipal"
}

# machine-api — Machine API Operator role on master and worker subnets
resource "azurerm_role_assignment" "machine_api_master_subnet" {
  scope              = azurerm_subnet.master.id
  role_definition_id = local.role.machine_api_subnet
  principal_id       = azurerm_user_assigned_identity.machine_api.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "machine_api_worker_subnet" {
  scope              = azurerm_subnet.worker.id
  role_definition_id = local.role.machine_api_subnet
  principal_id       = azurerm_user_assigned_identity.machine_api.principal_id
  principal_type     = "ServicePrincipal"
}

# aro-operator — ARO Operator role on master and worker subnets
resource "azurerm_role_assignment" "aro_operator_master_subnet" {
  scope              = azurerm_subnet.master.id
  role_definition_id = local.role.aro_operator_subnet
  principal_id       = azurerm_user_assigned_identity.aro_operator.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aro_operator_worker_subnet" {
  scope              = azurerm_subnet.worker.id
  role_definition_id = local.role.aro_operator_subnet
  principal_id       = azurerm_user_assigned_identity.aro_operator.principal_id
  principal_type     = "ServicePrincipal"
}

# ===========================================================================
# Section 3 — Operator identities → virtual network (vnet-level scope)
# ===========================================================================

# cloud-network-config — Network Operator role on the entire VNet
resource "azurerm_role_assignment" "cloud_network_config_vnet" {
  scope              = azurerm_virtual_network.aro.id
  role_definition_id = local.role.cloud_network_vnet
  principal_id       = azurerm_user_assigned_identity.cloud_network_config.principal_id
  principal_type     = "ServicePrincipal"
}

# file-csi-driver — File CSI Driver Operator role on the entire VNet
resource "azurerm_role_assignment" "file_csi_driver_vnet" {
  scope              = azurerm_virtual_network.aro.id
  role_definition_id = local.role.file_csi_vnet
  principal_id       = azurerm_user_assigned_identity.file_csi_driver.principal_id
  principal_type     = "ServicePrincipal"
}

# image-registry — Image Registry Operator role on the entire VNet
resource "azurerm_role_assignment" "image_registry_vnet" {
  scope              = azurerm_virtual_network.aro.id
  role_definition_id = local.role.image_registry_vnet
  principal_id       = azurerm_user_assigned_identity.image_registry.principal_id
  principal_type     = "ServicePrincipal"
}

# ===========================================================================
# Section 4 — ARO first-party Resource Provider SP → virtual network
#
# The "Azure Red Hat OpenShift RP" service principal needs a Contributor-
# equivalent role on the VNet so the control plane can manage networking.
# ===========================================================================

resource "azurerm_role_assignment" "aro_rp_vnet" {
  scope              = azurerm_virtual_network.aro.id
  role_definition_id = local.role.aro_rp_vnet
  principal_id       = data.azuread_service_principal.aro_rp.object_id
  principal_type     = "ServicePrincipal"
}
