# Terraform Infrastructure Reference

This document provides Terraform infrastructure details for Claude Code.

## Module Structure

```
terraform/
├── modules/
│   ├── gcp-project-setup/      # APIs, Cloud NAT
│   ├── gke-autopilot/          # GKE cluster
│   ├── gcp-service-account/    # Service account, IAM
│   ├── cloudsql/               # PostgreSQL instance
│   ├── k8s-namespace/          # Namespace, RBAC, secrets
│   └── database-bootstrap/     # PostgreSQL permissions
└── environments/
    └── staging/                # Staging environment config
```

## Key Features

- **Modular Design**: Six reusable Terraform modules
- **GKE Autopilot**: Managed Kubernetes with autoscaling
- **CloudSQL IAM Auth**: Passwordless database authentication
- **Workload Identity**: Secure GCP access for pods
- **Database Bootstrap**: Automated PostgreSQL permission setup

## Quick Start

```bash
# Prerequisites: Complete Terraform Executor Service Account setup
# See: terraform/docs/TERRAFORM_EXECUTOR_SETUP.md

cd terraform/environments/staging
terraform login
terraform init
terraform plan
terraform apply

# Get cluster credentials
terraform output -raw get_credentials_command | bash
```

**Provisioning Time**: 20-30 minutes (GKE cluster takes longest)

## Resources Created

- GKE Autopilot cluster (regional, private nodes)
- CloudSQL PostgreSQL 17 instance
- Cloud NAT (for private cluster egress)
- GCP Service Account (with Workload Identity)
- Kubernetes namespace, ServiceAccount, RBAC
- ImagePullSecret for ghcr.io
- Database permissions via temporary pod

## Critical Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| CloudSQL IAM Auth Flag | `cloudsql.iam_authentication=on` | MANDATORY, triggers restart |
| Workload Identity | Two-way binding | K8s SA ↔ GCP SA |
| Database Permissions | Via Terraform | Not Liquibase (chicken-and-egg) |
| Private Cluster | Yes | Requires Cloud NAT |

## Estimated Monthly Cost (Staging)

| Component | Cost |
|-----------|------|
| GKE Autopilot | ~$70-120 |
| CloudSQL | ~$100-150 |
| Cloud NAT | ~$45-60 |
| Ingress | ~$18-25 |
| **Total** | **~$233-355/month** |

## Terraform Output for Helm

```bash
terraform output -raw helm_values_yaml
```

## Documentation

- [Terraform Modules README](../../terraform/README.md)
- [Terraform Executor Setup](../../terraform/docs/TERRAFORM_EXECUTOR_SETUP.md)
- [Provisioning Guide](../../terraform/docs/PROVISIONING_GUIDE.md)

## Deployment Flow

1. Terraform provisions infrastructure
2. Helm deploys application containers
3. Liquibase runs database migrations
4. Application is accessible via ingress
