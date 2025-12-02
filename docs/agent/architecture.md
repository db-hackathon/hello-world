# Architecture Reference

This document provides detailed architecture information for Claude Code when working on this repository.

## Three-Tier Architecture Pattern

All applications follow this structure:

| Layer | Purpose | Technology |
|-------|---------|------------|
| Presentation | UI/frontend components | Flask, HTML templates |
| Application | Business logic, API endpoints | Flask REST API |
| Data | Database interactions | PostgreSQL, Liquibase |

## Baby Names Application Architecture

```
Frontend (Flask) :8080
    ↓
Backend API (Flask) :5000
    ↓
PostgreSQL :5432
```

### Components

- **Frontend**: Flask web app (Alpine-based, Python 3.11)
- **Backend**: REST API with `/api/v1/names` endpoints (Alpine-based, Python 3.11)
- **Database**: PostgreSQL 15 with Liquibase migrations
- **Data**: Real 2024 ONS boys' baby names dataset (50 names)

### Container Security

- Alpine Linux base images (zero CRITICAL vulnerabilities)
- SBOM attestation (SPDX format via Syft)
- Vulnerability scanning (Trivy)
- Build provenance attestation

## IDP Products

### K8s Cluster (Local Variant)

- **Location**: `products/k8s-cluster/local/`
- **Technology**: kind (Kubernetes in Docker)
- **Key Features**:
  - Configurable worker nodes
  - Port mappings for ingress
  - Namespace and service account creation
  - Generates both admin and service account kubeconfigs

## Helm Chart Features

- **IAM Database Authentication**: No passwords required, uses Google Cloud IAM
- **Cloud SQL Proxy**: Automatic sidecar container for secure connections
- **Workload Identity**: GKE pods authenticate to GCP via service accounts
- **Helm Hooks**: Database migrations run automatically before deployment
- **Health Probes**: Liveness and readiness checks for both services
- **Ingress**: GCE ingress controller for external access
- **Environment-specific values**: Separate values files for staging/production
- **Terraform Integration**: Namespace, ServiceAccount, RBAC, and secrets created by Terraform

## Infrastructure vs Application Separation

| Terraform Creates | Helm Creates |
|-------------------|--------------|
| GCP infrastructure | Deployments |
| Namespace | Services |
| ServiceAccount | Jobs |
| RBAC | Ingress |
| ImagePullSecret | |

**Key Rule**: Helm does NOT create Namespace or ServiceAccount - Terraform owns these.

## Adding New Applications

1. Create directory under `examples/`
2. Implement three tiers with clear separation
3. Add `docker-compose.yml` for local development
4. Create comprehensive tests (unit, integration, smoke)
5. Add CI/CD workflows
6. Document in README.md

## Working with IDP Products

IDP products are composable infrastructure components:

- Each product has variants (e.g., `local`, `gcp`, `aws`)
- Managed with Terraform
- Outputs can be consumed by other products or applications
- Follow the existing structure in `products/k8s-cluster/`
