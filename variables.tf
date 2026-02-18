# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

variable "location" {
  description = "Azure region where all resources will be deployed."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group that contains the cluster and its supporting resources."
  type        = string
  default     = "aro-rg"
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the Azure Red Hat OpenShift cluster."
  type        = string
  default     = "aro-cluster"
}

variable "domain" {
  description = "Short domain prefix used in the auto-generated OpenShift console/API DNS names and in the name of the managed infrastructure resource group."
  type        = string
}

variable "aro_version" {
  description = "Version of Azure Red Hat OpenShift to deploy. Use `az aro get-versions --location <region>` to list available versions."
  type        = string
  default     = "4.15.35"
}

variable "pull_secret" {
  description = "Optional Red Hat pull secret JSON string. Enables access to Red Hat container registries and OperatorHub content."
  type        = string
  default     = ""
  sensitive   = true
}

variable "fips_validated_modules" {
  description = "Enable FIPS validated crypto modules."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.fips_validated_modules)
    error_message = "Must be 'Enabled' or 'Disabled'."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the cluster virtual network."
  type        = string
  default     = "10.0.0.0/22"
}

variable "master_subnet_prefix" {
  description = "Address prefix for the master (control-plane) subnet. Must be /23 or smaller and within the VNet address space."
  type        = string
  default     = "10.0.0.0/23"
}

variable "worker_subnet_prefix" {
  description = "Address prefix for the worker subnet. Must not overlap the master subnet."
  type        = string
  default     = "10.0.2.0/23"
}

variable "pod_cidr" {
  description = "CIDR block assigned to the OpenShift SDN pod network."
  type        = string
  default     = "10.128.0.0/14"
}

variable "service_cidr" {
  description = "CIDR block for Kubernetes service VIPs."
  type        = string
  default     = "172.30.0.0/16"
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

variable "master_vm_size" {
  description = "VM SKU for the three master nodes."
  type        = string
  default     = "Standard_D8s_v3"
}

variable "worker_vm_size" {
  description = "VM SKU for worker nodes."
  type        = string
  default     = "Standard_D4s_v3"
}

variable "worker_count" {
  description = "Number of worker nodes (minimum 3 required for ARO)."
  type        = number
  default     = 3
}

variable "worker_disk_size_gb" {
  description = "OS disk size in GB for worker nodes (minimum 128 GB)."
  type        = number
  default     = 128
}

variable "master_encryption_at_host" {
  description = "Enable encryption-at-host for master VMs."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.master_encryption_at_host)
    error_message = "Must be 'Enabled' or 'Disabled'."
  }
}

variable "worker_encryption_at_host" {
  description = "Enable encryption-at-host for worker VMs."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.worker_encryption_at_host)
    error_message = "Must be 'Enabled' or 'Disabled'."
  }
}

# ---------------------------------------------------------------------------
# Visibility (public cluster)
# ---------------------------------------------------------------------------

variable "api_server_visibility" {
  description = "API server endpoint visibility."
  type        = string
  default     = "Public"

  validation {
    condition     = contains(["Public", "Private"], var.api_server_visibility)
    error_message = "Must be 'Public' or 'Private'."
  }
}

variable "ingress_visibility" {
  description = "Cluster ingress (router) visibility."
  type        = string
  default     = "Public"

  validation {
    condition     = contains(["Public", "Private"], var.ingress_visibility)
    error_message = "Must be 'Public' or 'Private'."
  }
}
