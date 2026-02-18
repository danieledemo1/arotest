output "resource_group_name" {
  description = "Resource group that contains the ARO cluster resource."
  value       = azurerm_resource_group.aro.name
}

output "cluster_name" {
  description = "Name of the ARO cluster."
  value       = azapi_resource.aro_cluster.name
}

output "cluster_id" {
  description = "Full Azure resource ID of the ARO cluster."
  value       = azapi_resource.aro_cluster.id
}

output "api_server_url" {
  description = "OpenShift API server URL."
  value       = try(jsondecode(azapi_resource.aro_cluster.output).properties.apiserverProfile.url, null)
}

output "console_url" {
  description = "OpenShift web console URL."
  value       = try(jsondecode(azapi_resource.aro_cluster.output).properties.consoleProfile.url, null)
}

output "api_server_ip" {
  description = "Public IP address of the API server (useful for DNS A record if using a custom domain)."
  value       = try(jsondecode(azapi_resource.aro_cluster.output).properties.apiserverProfile.ip, null)
}

output "ingress_ip" {
  description = "Public IP address of the cluster ingress router (useful for *.apps DNS A record)."
  value       = try(jsondecode(azapi_resource.aro_cluster.output).properties.ingressProfiles[0].ip, null)
}

output "aro_version" {
  description = "Deployed OpenShift version."
  value       = try(jsondecode(azapi_resource.aro_cluster.output).properties.clusterProfile.version, var.aro_version)
}

output "managed_resource_group" {
  description = "Name of the ARO-managed infrastructure resource group (contains cluster VMs, LBs, etc.)."
  value       = "aro-${var.domain}-${var.location}"
}

# ---------------------------------------------------------------------------
# Identity outputs
# ---------------------------------------------------------------------------

output "cluster_identity_client_id" {
  description = "Client ID of the aro-cluster managed identity."
  value       = azurerm_user_assigned_identity.cluster.client_id
}

output "cluster_identity_principal_id" {
  description = "Principal (object) ID of the aro-cluster managed identity."
  value       = azurerm_user_assigned_identity.cluster.principal_id
}
