# Terraform Infrastructure for Baby-Names Application

This directory contains Terraform modules and configurations to provision GCP and Kubernetes infrastructure for the baby-names application.

## Quick Start

```bash
# 1. Set up Terraform execution service account (one-time)
# See: docs/TERRAFORM_EXECUTOR_SETUP.md

# 2. Configure Terraform Cloud
# Edit environments/staging/backend.tf with your organization name

# 3. Provision infrastructure
cd environments/staging
terraform login
terraform init
terraform apply  # Takes ~20-30 minutes

# 4. Get cluster credentials
terraform output -raw get_credentials_command | bash

# 5. Deploy application via Helm
cd /home/sweeand/hello-world/examples/baby-names/helm/baby-names
helm upgrade --install baby-names . \
  --namespace baby-names-staging \
  --values values-staging.yaml \
  --wait --timeout 10m
```

## Architecture

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│                      GCP Project                            │
│                 extended-ascent-477308-m8                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐         ┌─────────────────┐             │
│  │  Cloud NAT   │◄────────│ GKE Autopilot   │             │
│  │ (nat-router) │         │ (private nodes) │             │
│  └──────────────┘         └────────┬────────┘             │
│                                    │                       │
│  ┌─────────────────┐              │  Workload Identity   │
│  │  CloudSQL PG 17 │              ▼                       │
│  │  IAM Auth: ON   │    ┌──────────────────┐             │
│  └────────┬────────┘    │ GCP Service Acct │             │
│           │             │ hello-world-stg  │             │
│           │             └──────────────────┘             │
│           │                       │                       │
│           │                       │ IAM Bindings         │
│           │                       ▼                       │
│           │         ┌──────────────────────────┐         │
│           │         │  Kubernetes Resources    │         │
│           │         │  - Namespace             │         │
│           └────────►│  - ServiceAccount (WI)   │         │
│                     │  - RBAC Role/Binding     │         │
│                     │  - ImagePullSecret       │         │
│                     └──────────────────────────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Module Dependency Chain

```
gcp-project-setup (APIs, Cloud NAT)
    │
    ├──► gke-autopilot (GKE cluster)
    │        │
    └────────┴──► gcp-service-account (App SA, IAM)
                      │
                      ├──► cloudsql (Instance, DB, IAM user)
                      │        │
                      └────────┴──► k8s-namespace (NS, SA, RBAC, Secrets)
                                        │
                                        ▼
                                    database-bootstrap (PostgreSQL permissions)
```

## Directory Structure

```
terraform/
├── modules/                        # Reusable Terraform modules
│   ├── gcp-project-setup/          # Enable APIs, create Cloud NAT
│   ├── gke-autopilot/              # Create GKE Autopilot cluster
│   ├── gcp-service-account/        # Create app SA, configure IAM
│   ├── cloudsql/                   # Create CloudSQL instance
│   ├── k8s-namespace/              # Create K8s prerequisites
│   └── database-bootstrap/         # Grant PostgreSQL permissions
│
├── environments/                   # Environment-specific configurations
│   └── staging/                    # Staging environment
│       ├── main.tf                 # Module orchestration
│       ├── variables.tf            # Variable definitions
│       ├── terraform.tfvars        # Staging values
│       ├── providers.tf            # Provider configurations
│       ├── backend.tf              # Terraform Cloud backend
│       └── outputs.tf              # Useful outputs
│
└── docs/                           # Documentation
    ├── TERRAFORM_EXECUTOR_SETUP.md # Service account setup guide
    └── PROVISIONING_GUIDE.md       # Step-by-step provisioning
```

## Terraform Modules

### [gcp-project-setup](modules/gcp-project-setup/)

**Purpose**: Foundation setup for GCP project

**Resources**:
- Enable required APIs (sqladmin, container, compute)
- Create Cloud NAT for private cluster egress

**Why**: Private GKE nodes need Cloud NAT to pull container images from ghcr.io

---

### [gke-autopilot](modules/gke-autopilot/)

**Purpose**: Create managed Kubernetes cluster

**Resources**:
- GKE Autopilot cluster (regional, private nodes)
- Workload Identity enabled
- Automatic scaling and updates

**Provisioning Time**: 10-15 minutes

---

### [gcp-service-account](modules/gcp-service-account/)

**Purpose**: Application workload identity

**Resources**:
- GCP Service Account
- IAM bindings (cloudsql.client, cloudsql.instanceUser)
- Workload Identity User role (binds K8s SA to GCP SA)

**Why**: Enables pods to authenticate to CloudSQL using IAM (passwordless)

---

### [cloudsql](modules/cloudsql/)

**Purpose**: Managed PostgreSQL database

**Resources**:
- CloudSQL PostgreSQL 17 instance
- Database (baby_names)
- IAM database user
- **CRITICAL**: `cloudsql.iam_authentication=on` flag

**Provisioning Time**: 5-10 minutes (plus restart for IAM flag)

**Why**: IAM authentication requires the flag to be enabled on the instance

---

### [k8s-namespace](modules/k8s-namespace/)

**Purpose**: Kubernetes prerequisites for application

**Resources**:
- Namespace
- ServiceAccount with Workload Identity annotation
- ImagePullSecret (for ghcr.io)
- RBAC Role and RoleBinding (for migration watcher)

**Why**: These resources must exist before Helm deployment

---

### [database-bootstrap](modules/database-bootstrap/)

**Purpose**: Grant PostgreSQL permissions to IAM user

**How It Works**:
1. Creates temporary pod (postgres:15-alpine + cloud-sql-proxy)
2. Connects as postgres user
3. Executes GRANT statements
4. Cleans up pod

**Why**: Creating CloudSQL IAM user only sets up authentication, not permissions. Liquibase can't run without CREATE permission on schema, creating a chicken-and-egg problem.

**Execution Time**: 30-60 seconds

---

## Key Concepts

### Workload Identity

Workload Identity allows Kubernetes pods to authenticate as GCP service accounts without service account keys.

**How it works**:
1. Kubernetes ServiceAccount annotated with `iam.gke.io/gcp-service-account`
2. GCP Service Account granted `roles/iam.workloadIdentityUser` to K8s SA
3. Pods using K8s SA can impersonate GCP SA
4. GCP SA has `roles/cloudsql.client` and `roles/cloudsql.instanceUser`

**Benefits**:
- No service account keys to manage
- Automatic key rotation
- Fine-grained access control

### CloudSQL IAM Authentication

CloudSQL supports passwordless authentication using GCP IAM.

**Requirements**:
1. Instance flag: `cloudsql.iam_authentication=on`
2. IAM database user created in CloudSQL
3. PostgreSQL GRANT statements executed
4. Application connects with service account credentials

**Database User Format**:
- CloudSQL user: `hello-world-staging@PROJECT.iam.gserviceaccount.com`
- PostgreSQL user: `hello-world-staging@PROJECT.iam.gserviceaccount.com.iam` (note `.iam` suffix)

### Private GKE Clusters

Private GKE clusters have nodes without external IPs for security.

**Requirements**:
- Cloud NAT for egress traffic (pull images, access APIs)
- Workload Identity for GCP access
- Cloud SQL Proxy for database connections

**Benefits**:
- Reduced attack surface
- Compliance with security policies
- No external IP costs

## Provisioning Process

### Prerequisites

1. **Terraform Execution Service Account**
   - See: [docs/TERRAFORM_EXECUTOR_SETUP.md](docs/TERRAFORM_EXECUTOR_SETUP.md)
   - Roles: serviceusage.serviceUsageAdmin, compute.networkAdmin, container.admin, iam.serviceAccountAdmin, iam.securityAdmin, cloudsql.admin, resourcemanager.projectIamAdmin

2. **Terraform Cloud Workspace**
   - Name: `baby-names-staging`
   - Environment variable: `GOOGLE_CREDENTIALS` (service account key JSON)
   - Terraform variable: `registry_password` (GitHub PAT with read:packages)

3. **GitHub Personal Access Token**
   - Scope: `read:packages` only
   - Access to: `db-hackathon/hello-world` repository

### First-Time Provisioning

**Step-by-step guide**: [docs/PROVISIONING_GUIDE.md](docs/PROVISIONING_GUIDE.md)

**Summary**:
```bash
cd environments/staging

# Update backend.tf with your organization
terraform init
terraform plan     # Review changes
terraform apply    # Provision infrastructure (~20-30 min)

# Get cluster credentials
terraform output -raw get_credentials_command | bash

# Verify
kubectl get namespace baby-names-staging
kubectl get sa baby-names-staging -n baby-names-staging
```

## Infrastructure vs Application

**Terraform manages**:
- GCP resources (GKE, CloudSQL, Cloud NAT, IAM)
- Kubernetes prerequisites (namespace, ServiceAccount, RBAC, secrets)
- Database permissions

**Helm manages** (deployed separately):
- Application pods (backend, frontend)
- Migration jobs (Liquibase)
- Services, Ingress
- Application configuration

**Separation of Concerns**:
- Infrastructure changes: Terraform
- Application deployment: CD pipeline with Helm
- Database schema: Liquibase migrations in application containers

## Cost Estimation

### Staging Environment (Monthly)

| Resource | Configuration | Est. Cost |
|----------|--------------|-----------|
| GKE Autopilot | Regional, ~2-4 vCPU | $70-120 |
| CloudSQL PostgreSQL | db-custom-2-8192 (2 vCPU, 8GB) | $100-150 |
| Cloud NAT | NAT Gateway + Data Processing | $45-60 |
| GCE Ingress | HTTP Load Balancer | $18-25 |
| **Total** | | **$233-355/month** |

### Cost Optimization

- **CloudSQL**: Use smaller tier (`db-custom-1-3840`) for staging (~$50 savings)
- **Availability**: Use ZONAL instead of REGIONAL (~50% savings on CloudSQL)
- **Development**: `terraform destroy` when not in use

## Troubleshooting

### Common Issues

**GKE Cluster Creation Timeout**:
- Normal behavior - Autopilot takes 10-15 minutes
- Run `terraform apply` again (idempotent)

**CloudSQL Instance Restart**:
- Enabling IAM authentication triggers restart (3-5 minutes)
- Expected on first apply

**Database Bootstrap Fails**:
- Check Workload Identity annotation on ServiceAccount
- Verify Cloud SQL Proxy can connect
- Check IAM roles on GCP service account

**ImagePullBackOff**:
- Verify `ghcr-secret` exists
- Check ServiceAccount has `imagePullSecrets`
- Verify GitHub PAT has `read:packages` scope
- Ensure Cloud NAT is configured

**Permission Denied**:
- Verify Terraform execution SA has required roles
- Check APIs are enabled
- Ensure correct project ID

## Maintenance

### Updating Infrastructure

```bash
cd environments/staging
terraform plan   # Review changes
terraform apply  # Apply updates
```

### Destroying Infrastructure

```bash
# 1. Disable deletion protection
# Edit terraform.tfvars:
# cluster_deletion_protection = false
# cloudsql_deletion_protection = false

terraform apply  # Apply protection changes

# 2. Destroy
terraform destroy  # Takes ~10-15 minutes
```

## Security Best Practices

1. **Service Account Keys**:
   - Store in Terraform Cloud as sensitive variables
   - Rotate every 90 days
   - Use Workload Identity Federation when possible (no keys)

2. **Secrets Management**:
   - Mark sensitive variables in Terraform Cloud
   - Never commit keys to version control
   - Use Google Secret Manager for application secrets

3. **Access Control**:
   - Principle of least privilege for all IAM roles
   - Regular audits of permissions
   - Enable Cloud Audit Logging

4. **Network Security**:
   - Private GKE clusters (no external IPs on nodes)
   - Cloud NAT for controlled egress
   - Firewall rules for ingress

## Documentation

- **[TERRAFORM_EXECUTOR_SETUP.md](docs/TERRAFORM_EXECUTOR_SETUP.md)**: Set up Terraform execution service account
- **[PROVISIONING_GUIDE.md](docs/PROVISIONING_GUIDE.md)**: Step-by-step first-time provisioning
- **Module READMEs**: Each module directory contains detailed documentation

## Support and Contributing

For issues or questions:
- Check individual module READMEs
- Review troubleshooting sections in PROVISIONING_GUIDE.md
- Examine Terraform Cloud run logs
- Inspect GCP Cloud Console for resource status

## Next Steps

After provisioning infrastructure:

1. **Deploy Application**: Use Helm chart in `examples/baby-names/helm/baby-names/`
2. **Verify Deployment**: Check pods, services, ingress
3. **Test Application**: Access via ingress URL
4. **Monitor Resources**: Set up monitoring and alerting
5. **Plan Production**: Adapt for production environment

## License

Same as parent repository.
