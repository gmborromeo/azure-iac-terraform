# Azure Infrastructure as Code with Terraform

A production-grade Azure infrastructure provisioned entirely via Terraform with a full CI/CD pipeline using GitHub Actions. Zero manual clicks — every resource is defined as code, versioned in git, and deployed automatically.

**Stack:** Terraform · Azure · GitHub Actions · Azure CLI · Bash

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub                               │
│                                                         │
│   Pull Request ──► terraform plan  (preview only)       │
│   Merge to main ──► terraform apply (deploys to Azure)  │
│                                                         │
│   Secrets: ARM_CLIENT_ID, ARM_CLIENT_SECRET,            │
│            ARM_SUBSCRIPTION_ID, ARM_TENANT_ID           │
└─────────────────────────┬───────────────────────────────┘
                          │ GitHub Actions
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    Azure                                │
│                                                         │
│   Resource Group                                        │
│   └── VNet (10.0.0.0/16)                                │
│       └── Subnet (10.0.1.0/24)                          │
│           └── NSG (SSH inbound only)                    │
│   └── Linux VM (Ubuntu 22.04)                           │
│       └── NIC + Public IP (Standard SKU)                │
│                                                         │
│   Storage Account ── Terraform remote state (tfstate)   │
└─────────────────────────────────────────────────────────┘
```

---

## Features

- Full Azure environment provisioned with Terraform — VNet, subnet, NSG, Linux VM, public IP
- Modular structure — separate `networking` and `vm` modules for reusability
- Remote state stored in Azure Blob Storage — survives CI/CD runs and team collaboration
- Environment separation via Terraform workspaces (dev / staging) with per-environment `.tfvars`
- GitHub Actions pipeline: `terraform plan` on PRs, `terraform apply` on merge to main
- Azure Service Principal with least-privilege Contributor RBAC — credentials never hardcoded
- Standard SKU public IP — aligned with Azure's recommended (Basic SKU retiring 2025)

---

## Provisioned Resources

| Resource | Dev | Staging |
|---|---|---|
| Resource Group | `iac-demo-dev-rg` | `iac-demo-staging-rg` |
| Virtual Network | `10.0.0.0/16` | `10.1.0.0/16` |
| Subnet | `10.0.1.0/24` | `10.1.1.0/24` |
| VM Size | Standard_B1s | Standard_B2s |
| NSG | SSH (port 22) inbound | SSH (port 22) inbound |

---

## Screenshots

**terraform plan output — resources to be created**

<img width="1143" height="588" alt="image" src="https://github.com/user-attachments/assets/f86692ae-f69b-4add-9ea2-29588dbbb522" />

**GitHub Actions — plan and apply steps passing**

<img width="1879" height="746" alt="image" src="https://github.com/user-attachments/assets/237e8fc2-2492-41ff-9e0d-76f0cec19721" />

**Azure Portal — provisioned resource group**

<img width="1892" height="648" alt="image" src="https://github.com/user-attachments/assets/aedd7e19-1e19-4e13-9da3-84ec22eca82d" />

**terraform workspace list**

<img width="540" height="86" alt="image" src="https://github.com/user-attachments/assets/77bc8c7b-3df3-4cd9-8cd7-9c6222ab5252" />

---

## Prerequisites

- Azure account with active subscription
- Azure CLI installed
- Terraform >= 1.5.0 installed
- GitHub account

---

## Local Setup

### 1. Clone the repository

```bash
git clone https://github.com/gmborromeo/azure-iac-terraform
cd azure-iac-terraform
```

### 2. Login to Azure

```bash
# Use device code flow (recommended for WSL)
az login --use-device-code
```

### 3. Create remote state storage (one-time setup)

```bash
az group create --name terraform-state-rg --location australiaeast

az storage account create \
  --name tfstateYOURUNIQUENAME \
  --resource-group terraform-state-rg \
  --sku Standard_LRS

az storage container create \
  --name tfstate \
  --account-name tfstateYOURUNIQUENAME
```

Update `backend.tf` with your storage account name.

### 4. Create a Service Principal

```bash
az ad sp create-for-rbac \
  --name "terraform-github-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
```

Save the JSON output — you'll need it for GitHub Secrets and local env vars.

### 5. Export credentials locally

```bash
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."
export ARM_SUBSCRIPTION_ID="..."
export ARM_TENANT_ID="..."
```

### 6. Create terraform.tfvars (gitignored)

```bash
cat > terraform.tfvars << EOF
project_name   = "iac-demo"
environment    = "dev"
ssh_public_key = "$(cat ~/.ssh/id_rsa.pub)"
EOF
```

### 7. Initialise and deploy

```bash
# Initialise with remote backend
terraform init

# Create and select dev workspace
terraform workspace new dev
terraform workspace select dev

# Preview changes
terraform plan -var-file=environments/dev.tfvars

# Deploy (type 'yes' when prompted)
terraform apply -var-file=environments/dev.tfvars
```

### 8. Destroy when done (avoids unnecessary cost)

```bash
terraform destroy -var-file=environments/dev.tfvars
```

---

## GitHub Actions — CI/CD Pipeline

The pipeline runs automatically on every push and pull request.

### How it works

| Event | Action |
|---|---|
| Pull request to main | `terraform plan` — shows what will change, no deployment |
| Merge to main | `terraform apply -auto-approve` — deploys to Azure |

The plan output is uploaded as a GitHub Actions artifact on every PR so reviewers can see exactly what infrastructure changes are proposed before approving.

### Adding secrets to GitHub

Go to repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret Name | Value |
|---|---|
| `ARM_CLIENT_ID` | from Service Principal JSON (`clientId`) |
| `ARM_CLIENT_SECRET` | from Service Principal JSON (`clientSecret`) |
| `ARM_SUBSCRIPTION_ID` | from Service Principal JSON (`subscriptionId`) |
| `ARM_TENANT_ID` | from Service Principal JSON (`tenantId`) |
| `SSH_PUBLIC_KEY` | contents of `~/.ssh/id_rsa.pub` |

---

## Terraform Workspaces

This project uses Terraform workspaces to manage environment separation. Each workspace has its own state file in Azure Blob Storage.

```bash
# List workspaces
terraform workspace list

# Switch to staging
terraform workspace select staging

# Deploy to staging
terraform apply -var-file=environments/staging.tfvars
```

---

## Project Files

```
azure-iac-terraform/
├── main.tf                      # Root module — calls networking and vm modules
├── variables.tf                 # Input variable declarations
├── backend.tf                   # Remote state config (Azure Blob Storage)
├── .gitignore             
├── environments/
│   ├── dev.tfvars               # Dev environment variables
│   └── staging.tfvars           # Staging environment variables
├── modules/
│   ├── networking/
│   │   ├── main.tf              # VNet, subnet, NSG, NSG association
│   │   ├── variables.tf         # Module input variables
│   │   └── outputs.tf           # subnet_id, vnet_id
│   └── vm/
│       ├── main.tf              # Public IP, NIC, Linux VM
│       ├── variables.tf         # Module input variables
│       └── outputs.tf           # public_ip, vm_id
├── docs/
│   ├── terraform-plan.png       # Screenshot
│   ├── github-actions.png       # Screenshot
│   ├── azure-portal.png         # Screenshot
│   └── terraform-workspaces.png # Screenshot
└── .github/
    └── workflows/
        └── terraform.yml        # CI/CD pipeline
```

---

## .gitignore

```
.terraform/
*.tfstate
*.tfstate.backup
terraform.tfvars
*.tfvars.json
.terraform.lock.hcl
crash.log
```

---

## Cost

All resources provisioned by this project fall within Azure's free tier or cost less than $0.50/day when running. Always run `terraform destroy` after testing to avoid unnecessary charges.

| Resource | Cost |
|---|---|
| Standard_B1s VM | ~$0.01/hour |
| Standard SKU Public IP | ~$0.004/hour |
| VNet, Subnet, NSG | Free |
| Storage Account (remote state) | ~$0.002/month |
