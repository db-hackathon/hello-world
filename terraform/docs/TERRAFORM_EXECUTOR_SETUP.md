# Terraform Executor Service Account Setup Guide

This document describes how to create and configure the GCP service account used by Terraform Cloud to provision the baby-names application infrastructure.

## Overview

The Terraform executor service account is separate from the application workload service account. It has elevated permissions to create and manage GCP and Kubernetes resources.

**Service Accounts:**
- **Terraform Executor SA**: Used by Terraform Cloud to provision infrastructure (this guide)
- **Application Workload SA**: Used by application pods to access CloudSQL (created by Terraform)

## Prerequisites

- GCP project: `extended-ascent-477308-m8`
- Terraform Cloud account (or Terraform Enterprise)
- `gcloud` CLI installed and authenticated as project owner/admin
- Billing enabled on the GCP project

## Step 1: Create Terraform Execution Service Account

```bash
# Set variables
export PROJECT_ID="extended-ascent-477308-m8"
export TF_SA_NAME="terraform-cloud-executor"
export TF_SA_EMAIL="${TF_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Create service account
gcloud iam service-accounts create ${TF_SA_NAME} \
  --display-name="Terraform Cloud Executor" \
  --description="Service account for Terraform Cloud to provision baby-names infrastructure" \
  --project=${PROJECT_ID}

# Verify creation
gcloud iam service-accounts describe ${TF_SA_EMAIL} --project=${PROJECT_ID}
```

## Step 2: Grant Required IAM Roles

### Option A: Granular Roles (Recommended for Production)

```bash
# Array of required roles
ROLES=(
  "roles/serviceusage.serviceUsageAdmin"
  "roles/compute.networkAdmin"
  "roles/container.admin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.securityAdmin"
  "roles/cloudsql.admin"
  "roles/resourcemanager.projectIamAdmin"
)

# Grant each role
for role in "${ROLES[@]}"; do
  echo "Granting ${role}..."
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${TF_SA_EMAIL}" \
    --role="${role}"
done

# Verify roles
gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${TF_SA_EMAIL}"
```

### Option B: Simpler Role Set (Good for Staging)

```bash
# Grant Editor + IAM permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${TF_SA_EMAIL}" \
  --role="roles/editor"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${TF_SA_EMAIL}" \
  --role="roles/iam.securityAdmin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${TF_SA_EMAIL}" \
  --role="roles/resourcemanager.projectIamAdmin"
```

## IAM Role Breakdown

| Role | Purpose | Resources Managed |
|------|---------|-------------------|
| `serviceusage.serviceUsageAdmin` | Enable/disable GCP APIs | sqladmin, container, compute APIs |
| `compute.networkAdmin` | Manage network resources | Cloud Router, Cloud NAT |
| `container.admin` | Manage GKE clusters | GKE Autopilot cluster, get credentials |
| `iam.serviceAccountAdmin` | Create service accounts | Application workload service account |
| `iam.securityAdmin` | Manage IAM bindings | Service account-level IAM bindings |
| `cloudsql.admin` | Manage CloudSQL | Instance, databases, users, flags |
| `resourcemanager.projectIamAdmin` | Set project IAM policy | Project-level IAM bindings |

**Note:** `roles/owner` is NOT recommended even though it simplifies setup - violates least privilege principle.

## Step 3: Enable Base APIs

Enable these APIs manually before running Terraform (required for Terraform to function):

```bash
gcloud services enable serviceusage.googleapis.com --project=${PROJECT_ID}
gcloud services enable cloudresourcemanager.googleapis.com --project=${PROJECT_ID}
gcloud services enable iam.googleapis.com --project=${PROJECT_ID}
```

Terraform will enable additional APIs (sqladmin, container, compute) during provisioning.

## Step 4: Create Service Account Key

### For Terraform Cloud

```bash
# Create key and download JSON
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=${TF_SA_EMAIL} \
  --project=${PROJECT_ID}

# Display key contents (for copying to Terraform Cloud)
cat terraform-key.json
```

**IMPORTANT:** Treat this key file as a secret! Do not commit to version control.

### For Workload Identity Federation (Alternative - More Secure)

If you have Terraform Cloud Business tier, you can use Workload Identity Federation instead of service account keys:

See: https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/gcp-configuration

## Step 5: Configure Terraform Cloud

### Create Workspace

1. Log in to Terraform Cloud: https://app.terraform.io
2. Navigate to your organization
3. Create new workspace:
   - Name: `baby-names-staging`
   - Execution mode: Remote
   - Terraform version: 1.5+ (latest recommended)

### Set Environment Variables

In the Terraform Cloud workspace, add these **environment variables**:

| Variable Name | Value | Sensitive | Description |
|---------------|-------|-----------|-------------|
| `GOOGLE_CREDENTIALS` | Contents of terraform-key.json | ✓ Yes | Service account key JSON |

**How to set:**
1. In workspace, go to Variables
2. Add variable
3. Select "Environment variable" category
4. Paste entire JSON contents (including `{ }`)
5. Mark as sensitive

### Set Terraform Variables

Add these **Terraform variables** (most have defaults in terraform.tfvars):

| Variable Name | Value | Sensitive | Required |
|---------------|-------|-----------|----------|
| `registry_password` | GitHub PAT with read:packages | ✓ Yes | Yes |
| `GOOGLE_PROJECT` | extended-ascent-477308-m8 | No | Optional |
| `GOOGLE_REGION` | europe-west1 | No | Optional |

**GitHub PAT Requirements:**
- Scope: `read:packages` only (least privilege)
- Never expires (or set long expiration)
- Belongs to user with access to db-hackathon/hello-world repository

## Step 6: Test Configuration

### Local Test (Optional)

Before using Terraform Cloud, you can test locally:

```bash
# Export service account credentials
export GOOGLE_CREDENTIALS=$(cat terraform-key.json)
export GOOGLE_PROJECT="extended-ascent-477308-m8"
export GOOGLE_REGION="europe-west1"

# Navigate to staging environment
cd terraform/environments/staging

# Initialize Terraform (skip backend for local test)
terraform init

# Validate configuration
terraform validate

# Plan (dry-run)
terraform plan
```

### Terraform Cloud Test

```bash
# Navigate to staging environment
cd terraform/environments/staging

# Login to Terraform Cloud
terraform login

# Update backend.tf with your organization name
# organization = "your-org-name"

# Initialize with Terraform Cloud backend
terraform init

# Plan
terraform plan

# If plan looks good, apply
terraform apply
```

## Kubernetes Access

The Terraform execution service account needs to execute `kubectl` commands during the database bootstrap step.

**How it works:**
1. Terraform uses `data.google_container_cluster` to get cluster details
2. Kubernetes provider authenticates using service account's access token
3. `kubectl` commands in shell scripts use cluster credentials from provider
4. Service account needs `roles/container.admin` for cluster access

**Verification:**
```bash
# After cluster is created, verify access
export KUBECONFIG=/tmp/test-kubeconfig
gcloud container clusters get-credentials hellow-world-manual \
  --region=europe-west1 \
  --project=${PROJECT_ID}

kubectl get nodes
kubectl get namespaces
```

## Security Best Practices

### Service Account Key Management

**DO:**
- ✓ Store key in Terraform Cloud as sensitive variable
- ✓ Rotate keys periodically (every 90 days recommended)
- ✓ Use Workload Identity Federation if available (no keys needed)
- ✓ Monitor service account usage via Cloud Logging
- ✓ Enable audit logs for service account activity

**DON'T:**
- ✗ Commit key to version control (add terraform-key.json to .gitignore)
- ✗ Share key via email or chat
- ✗ Store key in plaintext on local machine permanently
- ✗ Use same key across multiple environments

### Key Rotation

```bash
# List existing keys
gcloud iam service-accounts keys list \
  --iam-account=${TF_SA_EMAIL} \
  --project=${PROJECT_ID}

# Create new key
gcloud iam service-accounts keys create terraform-key-new.json \
  --iam-account=${TF_SA_EMAIL} \
  --project=${PROJECT_ID}

# Update Terraform Cloud with new key
# (Manual step in Terraform Cloud UI)

# Delete old key (after verifying new key works)
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=${TF_SA_EMAIL} \
  --project=${PROJECT_ID}
```

### Principle of Least Privilege

Review and remove unnecessary permissions periodically:

```bash
# Audit current roles
gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${TF_SA_EMAIL}" \
  --format="table(bindings.role)"

# Remove a role if not needed
gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${TF_SA_EMAIL}" \
  --role="roles/ROLE_NAME"
```

## Troubleshooting

### Permission Denied Errors

**Error:**
```
Error: Error creating Network: googleapi: Error 403: Required 'compute.networks.create' permission for 'projects/PROJECT_ID'
```

**Solution:**
- Verify service account has required roles
- Check roles were granted on correct project
- Ensure APIs are enabled

### API Not Enabled

**Error:**
```
Error: Error enabling service: Error enabling service ["SERVICE.googleapis.com"] for project "PROJECT_ID": googleapi: Error 403
```

**Solution:**
```bash
# Enable API manually
gcloud services enable SERVICE.googleapis.com --project=${PROJECT_ID}
```

### Invalid Credentials

**Error:**
```
Error: google: could not find default credentials
```

**Solution:**
- Verify GOOGLE_CREDENTIALS environment variable is set in Terraform Cloud
- Ensure JSON is valid (check for extra spaces or newlines)
- Regenerate service account key if corrupted

### Kubernetes Access Denied

**Error:**
```
Error: Failed to get Kubernetes cluster: container.clusters.get access denied
```

**Solution:**
- Verify service account has `roles/container.admin`
- Check cluster exists and name/region are correct
- Ensure GKE API is enabled

## Cleanup

To delete the Terraform execution service account (when no longer needed):

```bash
# List and delete all keys
for key_id in $(gcloud iam service-accounts keys list \
  --iam-account=${TF_SA_EMAIL} \
  --project=${PROJECT_ID} \
  --format="value(name)" \
  --filter="keyType:USER_MANAGED"); do
  gcloud iam service-accounts keys delete ${key_id} \
    --iam-account=${TF_SA_EMAIL} \
    --project=${PROJECT_ID} \
    --quiet
done

# Remove IAM policy bindings
for role in "${ROLES[@]}"; do
  gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${TF_SA_EMAIL}" \
    --role="${role}" \
    --quiet
done

# Delete service account
gcloud iam service-accounts delete ${TF_SA_EMAIL} \
  --project=${PROJECT_ID} \
  --quiet
```

## Next Steps

After completing this setup:
1. ✓ Service account created with required permissions
2. ✓ Terraform Cloud workspace configured
3. ✓ Credentials securely stored in Terraform Cloud

Proceed to:
- [PROVISIONING_GUIDE.md](./PROVISIONING_GUIDE.md) - First-time infrastructure provisioning
- [../README.md](../README.md) - Terraform modules overview
