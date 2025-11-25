# Infrastructure Provisioning Guide

This guide walks through the first-time provisioning of the baby-names application infrastructure using Terraform.

## Overview

**Total Provisioning Time:** 20-30 minutes

**Components Provisioned:**
1. Cloud NAT for private cluster egress (~2 min)
2. GKE Autopilot cluster (~10-15 min)
3. GCP Service Account with IAM bindings (~1 min)
4. CloudSQL PostgreSQL instance (~5-10 min)
5. Kubernetes namespace and prerequisites (~1 min)
6. Database permissions bootstrap (~1 min)

## Prerequisites

Before starting, ensure you have completed:

1. ✓ [Terraform Executor Service Account Setup](./TERRAFORM_EXECUTOR_SETUP.md)
2. ✓ Terraform Cloud workspace configured
3. ✓ GitHub Personal Access Token (PAT) with `read:packages` scope
4. ✓ `gcloud` CLI installed (for kubectl access after provisioning)
5. ✓ `kubectl` installed
6. ✓ Git repository cloned locally

## Step-by-Step Provisioning

### Step 1: Review Configuration

Navigate to the staging environment:

```bash
cd terraform/environments/staging
```

Review the configuration files:
- `terraform.tfvars` - Staging-specific values (mostly pre-configured)
- `variables.tf` - Variable definitions
- `backend.tf` - Terraform Cloud configuration

### Step 2: Configure Backend

Edit `backend.tf` and update with your Terraform Cloud organization name:

```hcl
terraform {
  cloud {
    organization = "your-org-name"  # <-- Update this

    workspaces {
      name = "baby-names-staging"
    }
  }
}
```

### Step 3: Set Sensitive Variables

In Terraform Cloud workspace, set the following **Terraform variables**:

| Variable | Value | How to Get |
|----------|-------|------------|
| `registry_password` | GitHub PAT | GitHub Settings → Developer settings → Personal access tokens → Generate new token (classic) → Select `read:packages` scope |

**Marking as Sensitive:**
1. In Terraform Cloud workspace, go to Variables
2. Add variable
3. Select "Terraform variable" category
4. Enter variable name and value
5. Check "Sensitive" checkbox
6. Save

### Step 4: Authenticate to Terraform Cloud

```bash
# Login to Terraform Cloud
terraform login

# Follow the prompts to authenticate via browser
```

### Step 5: Initialize Terraform

```bash
# Initialize Terraform (downloads providers, connects to backend)
terraform init

# Expected output:
# Terraform Cloud has been successfully initialized!
```

**Troubleshooting:**
- If you get authentication errors, run `terraform logout` then `terraform login` again
- If backend errors occur, verify organization name in `backend.tf`

### Step 6: Validate Configuration

```bash
# Validate Terraform configuration
terraform validate

# Expected output:
# Success! The configuration is valid.
```

### Step 7: Review Execution Plan

```bash
# Generate and review execution plan
terraform plan

# Review the plan output carefully
# Expected resources to be created: ~30-40 resources
```

**Key Resources in Plan:**
- `module.gcp_project_setup` - 5 resources (APIs, Cloud NAT)
- `module.gke_autopilot` - 1 resource (GKE cluster)
- `module.gcp_service_account` - 4 resources (SA, IAM bindings)
- `module.cloudsql` - 3 resources (instance, database, IAM user)
- `module.k8s_namespace` - 6 resources (namespace, SA, RBAC, secret)
- `module.database_bootstrap` - 2 resources (null_resource, random_password)

**Review Checklist:**
- [ ] All module dependencies are correct
- [ ] No unexpected deletions or replacements
- [ ] Sensitive values are properly marked (won't show in output)
- [ ] Resource names match expectations (cluster name, instance name, etc.)

### Step 8: Apply Configuration

```bash
# Apply Terraform configuration
terraform apply

# Review the plan one more time
# Type 'yes' when prompted to confirm
```

**What Happens During Apply:**

**Phase 1: GCP Project Setup (2-3 minutes)**
- Enabling APIs (sqladmin, container, compute)
- Creating Cloud Router
- Creating Cloud NAT configuration

**Phase 2: GKE Cluster (10-15 minutes)** ⏱️ _Longest step_
- Creating GKE Autopilot cluster
- Provisioning control plane
- Creating managed node pools

**Phase 3: Service Account (30 seconds)**
- Creating GCP service account
- Setting up IAM bindings

**Phase 4: CloudSQL Instance (5-10 minutes)** ⏱️
- Creating PostgreSQL instance
- Setting database flags (IAM authentication)
- Creating database and IAM user

**Phase 5: Kubernetes Resources (1-2 minutes)**
- Creating namespace
- Creating ServiceAccount with Workload Identity
- Creating ImagePullSecret
- Creating RBAC role and binding

**Phase 6: Database Bootstrap (1 minute)**
- Creating temporary pod
- Granting PostgreSQL permissions
- Cleaning up temporary resources

**Expected Total Time:** 20-30 minutes

### Step 9: Verify Provisioning

After successful `terraform apply`, verify the infrastructure:

#### Check Terraform Outputs

```bash
# View all outputs
terraform output

# View specific output
terraform output cluster_name
terraform output cloudsql_instance_connection_name
terraform output gcp_service_account_email
```

#### Get GKE Credentials

```bash
# Copy the command from terraform output
terraform output -raw get_credentials_command

# Or run directly:
gcloud container clusters get-credentials hellow-world-manual \
  --region=europe-west1 \
  --project=extended-ascent-477308-m8
```

#### Verify Kubernetes Resources

```bash
# Check namespace
kubectl get namespace baby-names-staging

# Check ServiceAccount
kubectl get sa baby-names-staging -n baby-names-staging -o yaml

# Verify Workload Identity annotation
kubectl get sa baby-names-staging -n baby-names-staging \
  -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'

# Expected output: hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com

# Check ImagePullSecret
kubectl get secret ghcr-secret -n baby-names-staging

# Check RBAC
kubectl get role,rolebinding -n baby-names-staging
```

#### Verify CloudSQL

```bash
# List CloudSQL instances
gcloud sql instances list --project=extended-ascent-477308-m8

# Describe instance
gcloud sql instances describe hello-world-manual \
  --project=extended-ascent-477308-m8

# Verify IAM authentication flag
gcloud sql instances describe hello-world-manual \
  --project=extended-ascent-477308-m8 \
  --format="value(settings.databaseFlags)"

# Expected output should include: cloudsql.iam_authentication=on

# List databases
gcloud sql databases list \
  --instance=hello-world-manual \
  --project=extended-ascent-477308-m8

# List database users
gcloud sql users list \
  --instance=hello-world-manual \
  --project=extended-ascent-477308-m8
```

#### Verify GCP IAM

```bash
# Check application service account
gcloud iam service-accounts describe \
  hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com \
  --project=extended-ascent-477308-m8

# Check IAM bindings
gcloud projects get-iam-policy extended-ascent-477308-m8 \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:hello-world-staging@*"
```

### Step 10: Deploy Application via Helm

After infrastructure is provisioned, deploy the application:

```bash
# Navigate to Helm chart directory
cd /home/sweeand/hello-world/examples/baby-names/helm/baby-names

# Deploy using Helm
helm upgrade --install baby-names . \
  --namespace baby-names-staging \
  --values values-staging.yaml \
  --set backend.image.tag=main \
  --set frontend.image.tag=main \
  --set migration.image.tag=main \
  --wait \
  --timeout 10m

# Expected output:
# Release "baby-names" has been upgraded. Happy Helming!
```

**Helm Deployment Steps:**
1. Creates migration job (runs Liquibase)
2. Waits for migration to complete
3. Creates backend deployment (2 replicas)
4. Creates frontend deployment (2 replicas)
5. Creates services (ClusterIP)
6. Creates ingress (GCE)

**Troubleshooting Helm Deployment:**

**ImagePullBackOff:**
```bash
# Check if secret exists
kubectl get secret ghcr-secret -n baby-names-staging

# Check SA has imagePullSecrets
kubectl get sa baby-names-staging -n baby-names-staging -o yaml | grep -A2 imagePullSecrets

# Test GitHub PAT manually
docker login ghcr.io -u andrewesweet -p <GITHUB_PAT>
```

**Migration Job Fails:**
```bash
# Check migration pod logs
kubectl logs -l app.kubernetes.io/component=migration -n baby-names-staging -c migration

# Check Cloud SQL Proxy logs
kubectl logs -l app.kubernetes.io/component=migration -n baby-names-staging -c cloud-sql-proxy

# Common issues:
# - IAM authentication not enabled (check database flags)
# - Postgres permissions not granted (check database-bootstrap logs)
# - Workload Identity not configured (check SA annotations)
```

**Init Containers Stuck:**
```bash
# Check init container logs
kubectl describe pod -l app.kubernetes.io/name=baby-names -n baby-names-staging

# Common issue: RBAC permissions
kubectl get role migration-watcher -n baby-names-staging
kubectl get rolebinding migration-watcher-binding -n baby-names-staging
```

### Step 11: Verify Application

```bash
# Check pods
kubectl get pods -n baby-names-staging

# Expected output:
# NAME                                  READY   STATUS      RESTARTS   AGE
# baby-names-backend-xxx-yyy            2/2     Running     0          2m
# baby-names-backend-xxx-zzz            2/2     Running     0          2m
# baby-names-frontend-xxx-yyy           1/1     Running     0          2m
# baby-names-frontend-xxx-zzz           1/1     Running     0          2m
# baby-names-migration-1                0/2     Completed   0          3m

# Check services
kubectl get svc -n baby-names-staging

# Check ingress
kubectl get ingress -n baby-names-staging

# Get ingress details
kubectl describe ingress baby-names -n baby-names-staging

# Wait for ingress to get external IP (2-5 minutes)
kubectl get ingress baby-names -n baby-names-staging -w
```

### Step 12: Test Application

```bash
# Get ingress host and IP
INGRESS_HOST=$(kubectl get ingress baby-names -n baby-names-staging \
  -o jsonpath='{.spec.rules[0].host}')

INGRESS_IP=$(kubectl get ingress baby-names -n baby-names-staging \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Ingress Host: ${INGRESS_HOST}"
echo "Ingress IP: ${INGRESS_IP}"

# Test frontend
curl -H "Host: ${INGRESS_HOST}" "http://${INGRESS_IP}/?name=Noah"

# Expected output: HTML page with baby name rank information

# Test backend API directly
curl -H "Host: ${INGRESS_HOST}" "http://${INGRESS_IP}/api/v1/names/Muhammad"

# Expected output: JSON with name rank data
```

## Common Issues and Solutions

### Issue: Terraform Timeout During GKE Creation

**Symptoms:**
```
Error: timeout while waiting for state to become 'DONE'
```

**Solution:**
- GKE Autopilot can take 10-15 minutes
- This is normal - wait for completion
- If timeout occurs, run `terraform apply` again (idempotent)

### Issue: CloudSQL Instance Restart

**Symptoms:**
```
Instance is restarting to apply configuration changes
```

**Solution:**
- Enabling IAM authentication flag triggers restart (3-5 minutes)
- This is expected on first apply
- Terraform will wait for restart to complete

### Issue: Database Bootstrap Fails

**Symptoms:**
```
Error: error executing local-exec: Pod failed to become ready
```

**Possible Causes:**
1. Workload Identity not configured
2. Cloud SQL Proxy can't connect
3. IAM roles missing

**Debug:**
```bash
# Check pod status
kubectl get pod psql-client-terraform -n baby-names-staging

# Check pod logs
kubectl logs psql-client-terraform -n baby-names-staging -c cloud-sql-proxy

# Check Workload Identity binding
gcloud iam service-accounts get-iam-policy \
  hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com \
  --project=extended-ascent-477308-m8
```

### Issue: Provider Authentication Errors

**Symptoms:**
```
Error: google: could not find default credentials
```

**Solution:**
- Verify GOOGLE_CREDENTIALS is set in Terraform Cloud
- Check service account key JSON is valid
- Regenerate key if corrupted

## Estimated Costs

**Monthly Costs (Staging Environment):**

| Resource | Configuration | Est. Monthly Cost |
|----------|--------------|-------------------|
| GKE Autopilot | Regional, ~2-4 vCPU | $70-120 |
| CloudSQL PostgreSQL | db-custom-2-8192 (2 vCPU, 8GB) | $100-150 |
| Cloud NAT | NAT Gateway + Data Processing | $45-60 |
| Ingress (GCE) | HTTP Load Balancer | $18-25 |
| **Total** | | **~$233-355/month** |

**Cost Optimization Tips:**
- Use smaller CloudSQL tier for staging: `db-custom-1-3840` (~$50/month savings)
- Use ZONAL availability instead of REGIONAL (~$50% savings on CloudSQL)
- Delete resources when not in use: `terraform destroy`

## Maintenance Operations

### Updating Infrastructure

```bash
# Pull latest Terraform configuration
git pull

# Review changes
terraform plan

# Apply changes
terraform apply
```

### Destroying Infrastructure

**WARNING:** This deletes all resources and data!

```bash
# Disable deletion protection first
# Edit terraform.tfvars:
# cluster_deletion_protection = false
# cloudsql_deletion_protection = false

terraform apply  # Apply the protection changes

# Then destroy
terraform destroy

# Type 'yes' to confirm

# Destruction time: ~10-15 minutes
```

## Next Steps

After successful provisioning:

1. ✓ Infrastructure is ready
2. ✓ Application deployed via Helm
3. ✓ Ingress accessible externally

Recommended next steps:
- Set up monitoring and alerting
- Configure backup verification
- Document custom configurations
- Set up staging → production promotion process
- Implement infrastructure drift detection

## Support

For issues or questions:
- Check module READMEs in `terraform/modules/`
- Review [TERRAFORM_EXECUTOR_SETUP.md](./TERRAFORM_EXECUTOR_SETUP.md)
- Check Terraform Cloud run logs
- Review GCP Cloud Console for resource status
