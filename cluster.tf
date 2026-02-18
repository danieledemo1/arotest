# ---------------------------------------------------------------------------
# Azure Red Hat OpenShift cluster
#
# The azapi provider is required here because the managed-identity deployment
# model uses platformWorkloadIdentityProfile, which is only available in
# the 2025-07-25 API version and is not yet surfaced by the azurerm provider.
#
# API reference:
#   Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25
# ---------------------------------------------------------------------------

resource "azapi_resource" "aro_cluster" {
  type      = "Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25"
  name      = var.cluster_name
  location  = azurerm_resource_group.aro.location
  parent_id = azurerm_resource_group.aro.id

  # Cluster identity — the single user-assigned MSI that ARO uses to federate
  # credentials for all operator identities at install time.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  # Disable schema validation so Terraform does not reject properties that are
  # valid in this API version but absent from the provider's bundled schema.
  schema_validation_enabled = false

  # Export all response properties so outputs can reference them.
  response_export_values = ["*"]

  body = jsonencode({
    properties = {

      # -----------------------------------------------------------------
      # Cluster profile
      # -----------------------------------------------------------------
      clusterProfile = {
        # Short label used in auto-generated DNS hostnames.
        domain = var.domain

        # ARO creates a separate managed resource group for infrastructure
        # VMs, load balancers, etc.  The name follows the convention
        # "aro-<domain>-<location>" and must not already exist.
        resourceGroupId = "/subscriptions/${local.sub_id}/resourceGroups/aro-${var.domain}-${var.location}"

        version            = var.aro_version
        fipsValidatedModules = var.fips_validated_modules

        # pull_secret is an empty string when not provided; the API accepts
        # an empty string and simply skips Red Hat registry registration.
        pullSecret = var.pull_secret
      }

      # -----------------------------------------------------------------
      # Network profile
      # -----------------------------------------------------------------
      networkProfile = {
        podCidr     = var.pod_cidr
        serviceCidr = var.service_cidr
      }

      # -----------------------------------------------------------------
      # Master (control-plane) profile — three nodes are always deployed.
      # -----------------------------------------------------------------
      masterProfile = {
        vmSize           = var.master_vm_size
        subnetId         = azurerm_subnet.master.id
        encryptionAtHost = var.master_encryption_at_host
      }

      # -----------------------------------------------------------------
      # Worker profile — one profile named "worker".
      # -----------------------------------------------------------------
      workerProfiles = [
        {
          name             = "worker"
          count            = var.worker_count
          diskSizeGB       = var.worker_disk_size_gb
          vmSize           = var.worker_vm_size
          subnetId         = azurerm_subnet.worker.id
          encryptionAtHost = var.worker_encryption_at_host
        }
      ]

      # -----------------------------------------------------------------
      # Visibility — public cluster (both API server and ingress exposed)
      # -----------------------------------------------------------------
      apiserverProfile = {
        visibility = var.api_server_visibility
      }

      ingressProfiles = [
        {
          name       = "default"
          visibility = var.ingress_visibility
        }
      ]

      # -----------------------------------------------------------------
      # Platform workload identity profile
      #
      # Each key is the well-known operator name that ARO expects.  The
      # value is the resource ID of the corresponding user-assigned MSI.
      # -----------------------------------------------------------------
      platformWorkloadIdentityProfile = {
        platformWorkloadIdentities = {
          "cloud-controller-manager" = {
            resourceId = azurerm_user_assigned_identity.cloud_controller_manager.id
          }
          "ingress" = {
            resourceId = azurerm_user_assigned_identity.ingress.id
          }
          "machine-api" = {
            resourceId = azurerm_user_assigned_identity.machine_api.id
          }
          "disk-csi-driver" = {
            resourceId = azurerm_user_assigned_identity.disk_csi_driver.id
          }
          "cloud-network-config" = {
            resourceId = azurerm_user_assigned_identity.cloud_network_config.id
          }
          "image-registry" = {
            resourceId = azurerm_user_assigned_identity.image_registry.id
          }
          "file-csi-driver" = {
            resourceId = azurerm_user_assigned_identity.file_csi_driver.id
          }
          "aro-operator" = {
            resourceId = azurerm_user_assigned_identity.aro_operator.id
          }
        }
      }
    }
  })

  # ---------------------------------------------------------------------------
  # Dependency ordering
  #
  # All role assignments must be in place before cluster creation begins,
  # otherwise the ARO RP will fail during network / identity validation.
  # ---------------------------------------------------------------------------
  depends_on = [
    # Section 1 — cluster identity → operator identities
    azurerm_role_assignment.cluster_to_ccm,
    azurerm_role_assignment.cluster_to_ingress,
    azurerm_role_assignment.cluster_to_machine_api,
    azurerm_role_assignment.cluster_to_disk_csi_driver,
    azurerm_role_assignment.cluster_to_cloud_network_config,
    azurerm_role_assignment.cluster_to_image_registry,
    azurerm_role_assignment.cluster_to_file_csi_driver,
    azurerm_role_assignment.cluster_to_aro_operator,

    # Section 2 — operator identities → subnets
    azurerm_role_assignment.ccm_master_subnet,
    azurerm_role_assignment.ccm_worker_subnet,
    azurerm_role_assignment.ingress_master_subnet,
    azurerm_role_assignment.ingress_worker_subnet,
    azurerm_role_assignment.machine_api_master_subnet,
    azurerm_role_assignment.machine_api_worker_subnet,
    azurerm_role_assignment.aro_operator_master_subnet,
    azurerm_role_assignment.aro_operator_worker_subnet,

    # Section 3 — operator identities → vnet
    azurerm_role_assignment.cloud_network_config_vnet,
    azurerm_role_assignment.file_csi_driver_vnet,
    azurerm_role_assignment.image_registry_vnet,

    # Section 4 — ARO RP SP → vnet
    azurerm_role_assignment.aro_rp_vnet,
  ]

  # Ignore changes that the ARO control plane may make to the worker profile
  # count or other mutable fields after initial provisioning to avoid
  # unintentional re-creates on subsequent plan/apply runs.
  lifecycle {
    ignore_changes = [
      body
    ]
  }

  timeouts {
    create = "90m"
    update = "60m"
    delete = "60m"
  }
}
