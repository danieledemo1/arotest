terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.13"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

provider "azuread" {}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

# Look up the ARO first-party Resource Provider service principal.
# This SP needs Contributor on the VNet so the RP can manage network resources.
data "azuread_service_principal" "aro_rp" {
  display_name = "Azure Red Hat OpenShift RP"
}

# ---------------------------------------------------------------------------
# Resource group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "aro" {
  name     = var.resource_group_name
  location = var.location
}
