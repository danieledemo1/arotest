# Azure Red Hat OpenShift (ARO) — Terraform Deployment with Managed Identity

Terraform configuration to deploy a **public Azure Red Hat OpenShift cluster** using **user-assigned managed identities**. The deployment uses the `azapi` provider to target the `Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25` API, which is required for the managed-identity deployment model.

---

## Prerequisites

| Requirement | Details |
|---|---|
| Terraform | >= 1.5.0 |
| Azure CLI | >= 2.77.0 |
| Azure subscription | Contributor + User Access Administrator (or Owner) on the target subscription |
| Microsoft Entra permissions | Member user or guest with **Application administrator** role |
| vCPU quota | Minimum 44 cores in the target region (Standard DSv5 or equivalent family) |

### Register required resource providers

Run the following commands once per subscription before the first deployment:

```bash
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait
```

---

## File structure

```
aroTest/
├── backend.tf           # Remote state backend (partial azurerm config; values passed at init time)
├── main.tf              # Provider configuration, resource group, data sources
├── variables.tf         # All input variables with descriptions and validation
├── terraform.tfvars     # Variable values — edit this file before deploying
├── network.tf           # Virtual network, master subnet, worker subnet
├── identities.tf        # Nine user-assigned managed identities
├── role_assignments.tf  # Twenty role assignments across four logical sections
├── cluster.tf           # ARO cluster resource (azapi provider)
└── outputs.tf           # Cluster API URL, console URL, IPs, identity IDs
```

### File responsibilities

| File | Resources |
|---|---|
| `backend.tf` | `azurerm` backend (partial config supplied via `terraform init -backend-config` flags) |
| `main.tf` | `azurerm_resource_group`, provider blocks, `data.azurerm_client_config`, `data.azuread_service_principal` (ARO RP) |
| `variables.tf` | All input variables with type constraints and validation rules |
| `terraform.tfvars` | Default values for all variables |
| `network.tf` | `azurerm_virtual_network`, `azurerm_subnet` (master), `azurerm_subnet` (worker) |
| `identities.tf` | Nine `azurerm_user_assigned_identity` resources |
| `role_assignments.tf` | Twenty `azurerm_role_assignment` resources grouped into four sections |
| `cluster.tf` | `azapi_resource` for `Microsoft.RedHatOpenShift/openShiftClusters` |
| `outputs.tf` | API server URL/IP, console URL, ingress IP, cluster ID, identity IDs |

---

## Key design decisions

### Why `azapi` instead of `azurerm`

The managed-identity deployment model requires the `platformWorkloadIdentityProfile` property, which is only available in API version `2025-07-25`. The `azurerm` Terraform provider does not yet expose this API version or this property. The `azapi` provider sends the ARM REST payload directly, making it compatible with the latest ARO API.

`schema_validation_enabled = false` is set on the cluster resource because the azapi provider's bundled schema does not include the `2025-07-25` definition.

### Providers used

| Provider | Source | Purpose |
|---|---|---|
| `azurerm` | `hashicorp/azurerm ~> 3.100` | Resource group, VNet, subnets, managed identities, role assignments |
| `azapi` | `azure/azapi ~> 1.13` | ARO cluster resource (managed-identity API version) |
| `azuread` | `hashicorp/azuread ~> 2.50` | Look up the ARO RP first-party service principal by display name |

### Lifecycle — `ignore_changes = [body]`

After initial provisioning, the ARO control plane may modify certain cluster properties (e.g. worker profile count during auto-scaling). The `ignore_changes = [body]` lifecycle rule prevents Terraform from treating these drift events as configuration changes that require re-apply.

### Subnet delegation drift — `ignore_changes = [delegation]`

After the ARO cluster is created, the control plane adds a `Microsoft.RedHatOpenShift/openShiftClusters` delegation to both the master and worker subnets. Because this delegation is not declared in the Terraform configuration, Terraform detects drift on every plan and attempts to remove it by recreating the subnets. The recreation is blocked by Azure because the cluster is deployed in those subnets, which also cascades into a forced recreation of every role assignment scoped to the subnets. Adding `lifecycle { ignore_changes = [delegation] }` on both subnet resources prevents this conflict.

### Role assignment dependency ordering

All twenty role assignments are listed in the `depends_on` block of the cluster resource. The ARO RP validates networking and identity permissions during cluster creation; if any assignment is missing the deployment will fail. Explicit `depends_on` ensures Terraform does not start the cluster create until all RBAC is in place.

### Managed infrastructure resource group

ARO automatically creates a second resource group named `aro-<domain>-<location>` to host infrastructure objects (VMs, load balancers, managed disks, etc.). This resource group is **not** managed by Terraform and is not deleted by `terraform destroy` — it must be removed manually or via `az aro delete`.

---

## Managed identities

ARO requires nine user-assigned managed identities. The table below lists each identity, its purpose, and the role assignments that must be in place before cluster creation.

### Operator identities — role assignments on network resources

| Identity | Role name | Role definition ID | Scope |
|---|---|---|---|
| `cloud-controller-manager` | Azure Red Hat OpenShift Cloud Controller Manager | `a1f96423-95ce-4224-ab27-4e3dc72facd4` | master subnet, worker subnet |
| `ingress` | Azure Red Hat OpenShift Ingress Operator | `0336e1d3-7a87-462b-b6db-342b63f7802c` | master subnet, worker subnet |
| `machine-api` | Azure Red Hat OpenShift Machine API Operator | `0358943c-7e01-48ba-8889-02cc51d78637` | master subnet, worker subnet |
| `aro-operator` | Azure Red Hat OpenShift ARO Operator | `4436bae4-7702-4c84-919b-c4069ff25ee2` | master subnet, worker subnet |
| `cloud-network-config` | Azure Red Hat OpenShift Network Operator | `be7a6435-15ae-4171-8f30-4a343eff9e8f` | virtual network |
| `file-csi-driver` | Azure Red Hat OpenShift File CSI Driver Operator | `0d7aedc0-15fd-4a67-a412-efad370c947e` | virtual network |
| `image-registry` | Azure Red Hat OpenShift Image Registry Operator | `8b32b316-c2f5-4ddf-b05b-83dacd2d08b5` | virtual network |
| `disk-csi-driver` | _(no network role required)_ | — | — |

### Cluster identity — role assignments on operator identities

The `aro-cluster` identity is the **cluster identity**. It is assigned **Managed Identity Operator** (`ef318e2a-8334-4a05-9e4a-295a196c6a6e`) on every operator identity listed above so it can federate their credentials at install time.

| Cluster identity | Role | Scope |
|---|---|---|
| `aro-cluster` | Managed Identity Operator | `cloud-controller-manager` MSI |
| `aro-cluster` | Managed Identity Operator | `ingress` MSI |
| `aro-cluster` | Managed Identity Operator | `machine-api` MSI |
| `aro-cluster` | Managed Identity Operator | `disk-csi-driver` MSI |
| `aro-cluster` | Managed Identity Operator | `cloud-network-config` MSI |
| `aro-cluster` | Managed Identity Operator | `image-registry` MSI |
| `aro-cluster` | Managed Identity Operator | `file-csi-driver` MSI |
| `aro-cluster` | Managed Identity Operator | `aro-operator` MSI |

### ARO Resource Provider service principal

The ARO first-party service principal (`"Azure Red Hat OpenShift RP"`) is looked up via the `azuread_service_principal` data source and assigned role `42f3c60f-e7b1-46d7-ba56-6de681664342` (Contributor-equivalent) on the virtual network.

---

## Variables reference

| Variable | Type | Default | Required | Description |
|---|---|---|---|---|
| `domain` | `string` | — | **yes** | Short prefix used in DNS hostnames and the managed resource group name |
| `location` | `string` | `italynorth` | no | Azure region |
| `resource_group_name` | `string` | `aro-rg` | no | Resource group name |
| `cluster_name` | `string` | `aro-cluster` | no | ARO cluster name |
| `aro_version` | `string` | `4.15.35` | no | OpenShift version to deploy |
| `pull_secret` | `string` | `""` | no | Red Hat pull secret JSON (sensitive) |
| `vnet_address_space` | `string` | `10.0.0.0/22` | no | VNet CIDR |
| `master_subnet_prefix` | `string` | `10.0.0.0/23` | no | Master subnet CIDR |
| `worker_subnet_prefix` | `string` | `10.0.2.0/23` | no | Worker subnet CIDR |
| `pod_cidr` | `string` | `10.128.0.0/14` | no | Pod network CIDR |
| `service_cidr` | `string` | `172.30.0.0/16` | no | Service network CIDR |
| `master_vm_size` | `string` | `Standard_D8s_v3` | no | Master node VM SKU |
| `worker_vm_size` | `string` | `Standard_D4s_v3` | no | Worker node VM SKU |
| `worker_count` | `number` | `3` | no | Number of worker nodes |
| `worker_disk_size_gb` | `number` | `128` | no | Worker OS disk size (GB) |
| `api_server_visibility` | `string` | `Public` | no | `Public` or `Private` |
| `ingress_visibility` | `string` | `Public` | no | `Public` or `Private` |
| `fips_validated_modules` | `string` | `Disabled` | no | `Enabled` or `Disabled` |
| `master_encryption_at_host` | `string` | `Disabled` | no | `Enabled` or `Disabled` |
| `worker_encryption_at_host` | `string` | `Disabled` | no | `Enabled` or `Disabled` |

Current sample values in [terraform.tfvars](terraform.tfvars):

| Variable | Value |
|---|---|
| `domain` | `myarotest` |
| `location` | `italynorth` |
| `resource_group_name` | `test-aro-identity-cluster-rg` |
| `cluster_name` | `aro-cluster` |
| `aro_version` | `4.19.20` |
| `master_vm_size` | `Standard_D8s_v5` |
| `worker_vm_size` | `Standard_D4s_v5` |
| `worker_count` | `3` |
| `worker_disk_size_gb` | `128` |
| `api_server_visibility` | `Public` |
| `ingress_visibility` | `Public` |

---

## Deployment instructions

### 1. Authenticate to Azure

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

Or use environment variables:

```bash
export ARM_SUBSCRIPTION_ID="<SUBSCRIPTION_ID>"
export ARM_TENANT_ID="<TENANT_ID>"
export ARM_CLIENT_ID="<CLIENT_ID>"
export ARM_CLIENT_SECRET="<CLIENT_SECRET>"
```

### 2. Register resource providers

```bash
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait
```

### 3. Check available ARO versions in your region

```bash
az aro get-versions --location eastus
```

Update `aro_version` in `terraform.tfvars` with the version you want to deploy.

### 4. (Optional) Obtain a Red Hat pull secret

1. Go to [https://console.redhat.com/openshift/install/azure/aro-provisioned](https://console.redhat.com/openshift/install/azure/aro-provisioned) and sign in.
2. Click **Download pull secret** and save `pull-secret.txt`.
3. Paste the contents as a single-line JSON string into `terraform.tfvars`:

```hcl
pull_secret = "{\"auths\":{...}}"
```

### 5. Configure `terraform.tfvars`

At minimum, set the `domain` value. All other variables have defaults.

```hcl
domain = "myaro"   # must be lowercase alphanumeric + hyphens
```

### 6. Initialise Terraform

```bash
terraform init
```

### 7. Review the execution plan

```bash
terraform plan -out=aro.tfplan
```

Review the output and confirm the expected resources are listed (resource group, VNet, 2 subnets, 9 managed identities, 20 role assignments, 1 ARO cluster).

### 8. Apply the deployment

```bash
terraform apply aro.tfplan
```

> **Note:** Cluster creation typically takes 30–45 minutes. The `azapi_resource` block has a 90-minute create timeout configured.

### 9. Retrieve cluster credentials

After apply completes, retrieve the `kubeadmin` credentials:

```bash
az aro list-credentials \
  --name <cluster_name> \
  --resource-group <resource_group_name>
```

The console URL is available from Terraform outputs:

```bash
terraform output console_url
terraform output api_server_url
```

---

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Resource group containing the cluster resource |
| `cluster_name` | ARO cluster name |
| `cluster_id` | Full Azure resource ID of the cluster |
| `api_server_url` | OpenShift API server URL (`https://api.<domain>.<location>.aroapp.io:6443`) |
| `console_url` | OpenShift web console URL |
| `api_server_ip` | Public IP of the API server |
| `ingress_ip` | Public IP of the ingress router |
| `aro_version` | Deployed OpenShift version |
| `managed_resource_group` | Name of the ARO-managed infrastructure resource group |
| `oidc_issuer_url` | Cluster OIDC issuer URL (use when creating federated credentials for managed identities) |
| `cluster_identity_client_id` | Client ID of the `aro-cluster` managed identity |
| `cluster_identity_principal_id` | Principal ID of the `aro-cluster` managed identity |

### Custom domain DNS records

If you supply a custom `domain` that maps to a real DNS zone, create two A records after deployment:

```
api.<domain>     →  <api_server_ip>
*.apps.<domain>  →  <ingress_ip>
```

---

## Teardown

```bash
terraform destroy
```

> **Important:** `terraform destroy` removes the cluster resource and all Terraform-managed resources, but the ARO-managed infrastructure resource group (`aro-<domain>-<location>`) is created by the ARO RP and is **not** tracked by Terraform state. Delete it manually:

```bash
az group delete --name "aro-<domain>-<location>" --yes --no-wait
```

---

## CI/CD — GitHub Actions

### Workflow file

`.github/workflows/terraform.yml`

### Job overview

```
pull_request → main     validate ──→ plan  (plan posted as PR comment)
push         → main     validate ──→ plan ──→ apply  (only if changes detected)
workflow_dispatch plan  validate ──→ plan
workflow_dispatch apply validate ──→ plan ──→ apply
workflow_dispatch destroy validate ──────────────→ destroy
```

| Job | Trigger | Environment gate |
|---|---|---|
| `validate` | All triggers | None |
| `plan` | All except `workflow_dispatch destroy` | None |
| `apply` | Push to `main` with changes, or manual `apply` | `production` |
| `destroy` | Manual `workflow_dispatch destroy` only | `production-destroy` |

### State backend — Azure Blob Storage

`backend.tf` uses a **partial configuration** pattern — no values are hard-coded. All backend settings are passed as `-backend-config` flags at `terraform init` time in the workflow.

#### Step 1 — Bootstrap the storage account

Run this once before the first deployment. Requires Contributor on the target subscription.

```bash
LOCATION="eastus"
BACKEND_RG="tfstate-rg"
STORAGE_ACCOUNT="tfstate$(openssl rand -hex 4)"   # must be globally unique
CONTAINER="tfstate"

az group create \
  --name "$BACKEND_RG" \
  --location "$LOCATION"

az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$BACKEND_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login
```

Grant the OIDC service principal permission to read and write the state blob:

```bash
SP_OBJECT_ID=$(az ad sp show --id "$ARM_CLIENT_ID" --query id -o tsv)
STORAGE_ID=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$BACKEND_RG" \
  --query id -o tsv)

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID"
```

### Step 2 — Create an Azure App Registration with Federated Credentials (OIDC)

```bash
APP_ID=$(az ad app create --display-name "github-aro-terraform" --query appId -o tsv)
SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)

# Contributor on the subscription (adjust to a narrower scope if preferred)
az role assignment create \
  --assignee-object-id "$SP_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# User Access Administrator — required to create role assignments for ARO identities
az role assignment create \
  --assignee-object-id "$SP_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

Add a federated credential so GitHub can exchange an OIDC token for an Azure access token:

```bash
GITHUB_ORG="<your-github-org-or-username>"
GITHUB_REPO="<your-repo-name>"

# For push to main (apply job)
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"github-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# For pull requests (plan job)
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"github-pr\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
```

### Step 3 — Configure GitHub Actions Variables and Secrets

Navigate to **Settings → Secrets and variables → Actions** in your GitHub repository.

#### Variables (non-sensitive)

| Variable | Value |
|---|---|
| `ARM_CLIENT_ID` | App registration client ID |
| `ARM_TENANT_ID` | Azure AD tenant ID |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID |
| `TF_BACKEND_RESOURCE_GROUP` | Resource group of the storage account (e.g. `tfstate-rg`) |
| `TF_BACKEND_STORAGE_ACCOUNT` | Storage account name |
| `TF_BACKEND_CONTAINER` | Blob container name (e.g. `tfstate`) |
| `TF_BACKEND_KEY` | State file path (e.g. `aro/terraform.tfstate`) |
| `TF_VAR_DOMAIN` | ARO domain prefix (e.g. `myaro`) |
| `TF_VAR_LOCATION` | Azure region (e.g. `eastus`) |
| `TF_VAR_RESOURCE_GROUP_NAME` | ARO resource group name |
| `TF_VAR_CLUSTER_NAME` | ARO cluster name |
| `TF_VAR_ARO_VERSION` | OpenShift version (e.g. `4.15.35`) |

#### Secrets (sensitive)

| Secret | Value |
|---|---|
| `TF_VAR_PULL_SECRET` | Red Hat pull secret JSON string (optional) |

### Step 4 — Configure GitHub Environments

Navigate to **Settings → Environments** and create two environments:

| Environment | Purpose | Recommended protection rules |
|---|---|---|
| `production` | Gates the `apply` job | Required reviewers, deployment branch `main` |
| `production-destroy` | Gates the `destroy` job | Required reviewers, deployment branch `main` |

### Pull request behaviour

When a PR is opened or updated against `main`, the workflow:

1. Validates formatting and HCL syntax.
2. Runs `terraform plan` against the live state.
3. Posts (or updates) a comment on the PR with a summary table and collapsible full plan output.

Merging the PR to `main` triggers the `apply` job automatically if the plan detected changes.

### Manual operations

| Goal | Steps |
|---|---|
| Preview changes without applying | `Actions → Terraform — ARO Cluster → Run workflow → action: plan` |
| Apply changes manually | `Actions → Terraform — ARO Cluster → Run workflow → action: apply` |
| Destroy the cluster | `Actions → Terraform — ARO Cluster → Run workflow → action: destroy` |

---

## References

- [Create an ARO cluster with managed identities (Microsoft Docs)](https://learn.microsoft.com/azure/openshift/howto-create-openshift-cluster)
- [Understanding managed identities in ARO](https://learn.microsoft.com/azure/openshift/howto-understand-managed-identities)
- [azapi Terraform provider](https://registry.terraform.io/providers/azure/azapi/latest/docs)
- [ARO networking concepts](https://learn.microsoft.com/azure/openshift/concepts-networking)
