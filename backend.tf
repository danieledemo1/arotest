# ---------------------------------------------------------------------------
# Remote state backend — Azure Blob Storage
#
# This is a PARTIAL backend configuration.  The sensitive and environment-
# specific values (storage account name, container, key) are intentionally
# omitted here and supplied at `terraform init` time via -backend-config
# flags in the GitHub Actions workflow, keeping this file safe to commit.
#
# Partial config reference:
#   https://developer.hashicorp.com/terraform/language/backend#partial-configuration
#
# Storage account bootstrap
# ─────────────────────────
# Run the following script once to create the storage account before the
# first `terraform init`.  The account must exist before Terraform can
# initialise the backend.
#
#   LOCATION="eastus"
#   BACKEND_RG="tfstate-rg"
#   STORAGE_ACCOUNT="tfstate$(openssl rand -hex 4)"   # globally unique name
#   CONTAINER="tfstate"
#
#   az group create \
#     --name "$BACKEND_RG" \
#     --location "$LOCATION"
#
#   az storage account create \
#     --name "$STORAGE_ACCOUNT" \
#     --resource-group "$BACKEND_RG" \
#     --location "$LOCATION" \
#     --sku Standard_LRS \
#     --kind StorageV2 \
#     --https-only true \
#     --min-tls-version TLS1_2 \
#     --allow-blob-public-access false
#
#   az storage container create \
#     --name "$CONTAINER" \
#     --account-name "$STORAGE_ACCOUNT" \
#     --auth-mode login
#
#   # Grant the OIDC service principal Storage Blob Data Contributor so it
#   # can read and write the state file.
#   SP_OBJECT_ID=$(az ad sp show --id "$ARM_CLIENT_ID" --query id -o tsv)
#   STORAGE_ID=$(az storage account show \
#     --name "$STORAGE_ACCOUNT" \
#     --resource-group "$BACKEND_RG" \
#     --query id -o tsv)
#
#   az role assignment create \
#     --assignee-object-id "$SP_OBJECT_ID" \
#     --assignee-principal-type ServicePrincipal \
#     --role "Storage Blob Data Contributor" \
#     --scope "$STORAGE_ID"
#
#   echo "Set in GitHub Actions Variables:"
#   echo "  TF_BACKEND_RESOURCE_GROUP  = $BACKEND_RG"
#   echo "  TF_BACKEND_STORAGE_ACCOUNT = $STORAGE_ACCOUNT"
#   echo "  TF_BACKEND_CONTAINER       = $CONTAINER"
#   echo "  TF_BACKEND_KEY             = aro/terraform.tfstate"
# ---------------------------------------------------------------------------

terraform {
  backend "azurerm" {
    # All configuration values are passed via -backend-config flags at
    # terraform init time.  See .github/workflows/terraform.yml and the
    # bootstrap script above.
    #
    # Values that will be supplied:
    #   resource_group_name  = "<TF_BACKEND_RESOURCE_GROUP>"
    #   storage_account_name = "<TF_BACKEND_STORAGE_ACCOUNT>"
    #   container_name       = "<TF_BACKEND_CONTAINER>"
    #   key                  = "<TF_BACKEND_KEY>"
    #   use_oidc             = true
  }
}
