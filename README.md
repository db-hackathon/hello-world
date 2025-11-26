# Hello, World!
This is the "hello world" three tier web app to be used for baseline examples and deployments using the Internal Developer Platforms.

## Structure

This repository provides a monorepo containing three composable IDP products and a reference implementation demonstrating their usage.

### Product Catalog

The repository defines three products that can be advertised and consumed via IDPs:

#### 1. K8s Cluster Product (`/products/k8s-cluster/`)

Creates a Kubernetes cluster in the user's chosen hosting venue with full networking and access management.

**Implementations:**
- **Public Cloud**: GKE on Google Cloud Platform
- **Private Cloud**: k3s on Ubuntu VM (suitable for local development)

**Inputs:**
- Venue selection (public/private cloud)
- Cluster name and configuration
- Networking preferences

**Outputs:**
- Cluster credentials (kubectl config)
- Namespace name for workload deployment
- Kubernetes service account name for workload identity
- Networking details (IPs, endpoints)

**Structure:** Terraform wrapper module (`main.tf`) that delegates to venue-specific implementations in `/gke/` and `/local/` subdirectories.

#### 2. PostgreSQL Product (`/products/postgresql/`)

Creates a PostgreSQL database instance with initial schema and user management.

**Implementations:**
- **Public Cloud**: Cloud SQL PostgreSQL on GCP
- **Private Cloud**: PostgreSQL on VM or in container (local storage)

**Inputs:**
- Venue selection (public/private cloud)
- Database name and sizing configuration
- Initial schema requirements

**Outputs:**
- Connection details (host, port, database name)
- Schema deployment role credentials (for migrations)
- Workload user credentials (for application runtime)

**Structure:** Terraform wrapper module (`main.tf`) that delegates to venue-specific implementations in `/cloud-sql/` and `/local/` subdirectories.

#### 3. Three Tier Web App Product (`/products/three-tier-webapp/`)

Composes the K8s Cluster and PostgreSQL products to provide a complete "golden path to production" for three-tier web applications.

**Capabilities:**
- Creates GitHub repository for the application (if needed)
- Provisions infrastructure using K8s Cluster + PostgreSQL products
- Creates complete CI/CD pipelines (GitHub Actions)
- Provisions dev and prod environments
- Handles networking and credential management automatically
- Parameterized to support different applications

**Inputs:**
- Application name
- Venue selection for each environment (dev, prod)
- Application-specific configuration

**Outputs:**
- GitHub repository URL
- Environment URLs (dev, prod)
- Infrastructure details from composed products

**Reference Implementation:** Baby names application (see below)

### Reference Application: Baby Names

Location: `/examples/baby-names/`

A production-ready three-tier web application that queries UK Office of National Statistics baby names data (2024 boys names dataset). Features comprehensive CI/CD with security scanning and supply chain attestations.

**Architecture:**
- **Frontend**: Python 3.11 Flask application serving HTML UI (Alpine-based)
- **Backend**: Python 3.11 Flask application providing REST API (Alpine-based)
- **Database**: PostgreSQL 15 with ONS dataset loaded via Liquibase

**Components:**
- `/examples/baby-names/frontend/` - Flask web UI with HTML templates
- `/examples/baby-names/backend/` - Flask REST API with `/api/v1/names` endpoints
- `/examples/baby-names/database/` - Liquibase changelogs and data migrations
- `/examples/baby-names/helm/baby-names/` - Helm chart for Kubernetes deployment
- Configuration files: `ruff.toml`, `.safety-policy.yml`
- Build system: Makefiles (root + component-level)

**API Endpoints:**
- `GET /` - Web UI home page with search form
- `GET /api/v1/names/{name}` - Returns popularity rank for given name (JSON)
- `GET /api/v1/names` - Returns all names (supports `limit` parameter)
- `GET /health` - Health check endpoint

**Security & Quality:**
- Alpine Linux base images (zero CRITICAL CVEs)
- SBOM generation and attestation (Syft/SPDX)
- Container vulnerability scanning (Trivy)
- Dependency vulnerability scanning (Safety)
- Code quality: Ruff linting and formatting
- Test coverage: 93% backend, 99% frontend
- GitHub Actions attestations for all artifacts

**Local Development:**
```bash
cd examples/baby-names

# Start services (Docker/Podman)
docker-compose up -d

# Run CI pipeline locally
export PATH="$HOME/.local/bin:$PATH"
make ci-local

# Stop services
docker-compose down -v
```

**GKE Deployment:**

The application can be deployed to Google Kubernetes Engine (GKE) using the included Helm chart.

**Prerequisites:** Terraform must create the namespace, ServiceAccount, RBAC, and secrets first:
```bash
cd terraform/environments/staging
terraform apply
```

**Deploy with Helm:**
```bash
cd examples/baby-names/helm/baby-names

# Deploy to staging (namespace created by Terraform)
helm upgrade --install baby-names . \
  --namespace baby-names-staging \
  --values values-staging.yaml \
  --set backend.image.tag=main-abc123 \
  --set frontend.image.tag=main-abc123 \
  --set migration.image.tag=main-abc123

# Check deployment status
kubectl get pods -n baby-names-staging
kubectl get ingress -n baby-names-staging
```

**Deployment Features:**
- **Terraform/Helm Separation**: Clear resource ownership - Terraform creates prerequisites (Namespace, ServiceAccount, RBAC, Secrets), Helm deploys only application workloads
- **IAM Database Authentication**: No passwords required, uses Google Cloud IAM
- **Cloud SQL Proxy**: Automatic sidecar for secure database connections
- **Workload Identity**: GKE pods authenticate to GCP services via service accounts
- **Automated Migrations**: Liquibase migrations run via init job before deployment
- **Health Checks**: Liveness and readiness probes for both frontend and backend
- **Ingress**: GCE ingress controller for external access

### CI/CD Pipeline Architecture

Location: `/.github/workflows/ci.yml`

**Three-Phase Pipeline with Fail-Fast Quality Gates:**

**Phase A - Sequential Quality Gates:**
1. **Format & Lint** (backend, frontend)
   - Ruff formatting check and linting
   - Delegates to `make format-check` and `make lint`
   - Generates and attests lint results (JSON)
2. **Dependency Security** (backend, frontend)
   - Safety vulnerability scanning
   - Delegates to `make security-check`
   - Fails on CRITICAL vulnerabilities only
   - Generates and attests security reports (JSON)
3. **Unit Tests** (backend, frontend)
   - Pytest with coverage reporting
   - Delegates to `make test`
   - Generates and attests coverage reports (XML)

**Phase B - Parallel Build & Scan:**
For each component (backend, frontend, db-migration):
1. **Build**: Delegates to `make build`
2. **SBOM Generation**: Delegates to `make generate-sbom` (Syft/SPDX)
3. **Vulnerability Scan**: Delegates to `make scan` (Trivy)
4. **Attestations**:
   - SBOM attestation (subject: container image)
   - Scan results attestation (subject: trivy-results.json)
   - Build provenance attestation (subject: container image)
5. **Push**: Registry push (non-PR builds only)
6. **Job Summary**: Outputs container details (registry URL, digest) directly to GitHub Actions job summary

**Phase C - Integration Tests:**
1. **Service Deployment**: Start full stack with docker-compose
2. **Health Checks**: Verify backend and frontend endpoints
3. **Integration Testing**: Run pytest integration test suite
4. **Cleanup**: Tear down docker-compose services

**Key Features:**
- All CI commands execute via Makefiles (single source of truth)
- Local execution: `make ci-local` runs identical pipeline
- GitHub Actions attestations for supply chain security
- Alpine-based images with zero CRITICAL vulnerabilities
- Comprehensive artifact collection: lint results, security reports, coverage, SBOMs, scan results

**Tools:**
- Ruff 0.8.4 (linting/formatting)
- Safety 2.3.5 (dependency scanning)
- Syft (SBOM generation)
- Trivy (container scanning)
- Pytest (testing with coverage)

### CD Pipeline

Location: `/.github/workflows/cd.yml`

**Deployment to Staging:**
1. **Authentication**: Direct Workload Identity Federation (WIF) to GCP
2. **GKE Access**: Configure kubectl with cluster credentials
3. **Helm Deployment**: Deploy using Helm chart with staging values
4. **Health Verification**: Check pod and service status
5. **Smoke Tests**: Verify frontend, backend, and database connectivity

**Security Features:**
- **Direct WIF**: No service account keys, uses GitHub OIDC tokens
- **IAM Database Auth**: CloudSQL authentication via service account identity
- **Workload Identity**: GKE service accounts bound to GCP service accounts
- **Cloud SQL Proxy**: Automatic IAM token refresh for database connections

**Future: Production Deployment:**
- Manual approval via GitHub Environments
- Blue-green or canary deployment strategy
- Gradual traffic shifting
- Automatic rollback on failure

### Deployment Targets

#### Public Cloud (GCP)
- **Kubernetes**: Google Kubernetes Engine (GKE)
- **Database**: Cloud SQL PostgreSQL
- **Infrastructure**: Terraform modules using official Google provider modules
- **Authentication**: GitHub Workload Identity Federation (planned)

#### Private Cloud (Local)
- **Kubernetes**: k3s on Ubuntu VM
- **Database**: PostgreSQL on separate Ubuntu VM (direct install or container)
- **Infrastructure**: Terraform modules for VM provisioning
- **Networking**: VMs on same network for simplicity
- **Local Development**: Runnable on developer's Ubuntu workstation

**Infrastructure Management:**
- All infrastructure defined in Terraform
- Separate Terraform module per component (GKE, Cloud SQL, k3s, Postgres VM)
- Reuse official vendor modules where available (Google modules for GCP)
- VM provisioning via cloud-init scripts
- Pre-built VM images using Packer (if needed)

### Local Development

**Application Development:**
- Docker Compose setup for Flask + Postgres
- Run full stack locally: `docker-compose up`
- Hot reload for development iteration

**Infrastructure Development:**
- Scripts for setting up local k3s cluster
- VM creation automation for private cloud testing
- Terraform modules testable locally

Location: `/docker-compose.yml`, `/scripts/local-setup/`

### Security & Credentials

**Current Approach:**
- GitHub Secrets for storing credentials
- Separate secrets per environment (dev, prod)

**Planned Improvements:**
- Keyless authentication using GitHub Workload Identity Federation
- Trust relationship between GitHub repo branches and GCP service accounts
- Example: prod branch can impersonate `gke-deployer` service account
- Eliminates long-lived credentials

**Product Outputs:**
- K8s Cluster: Credentials for cluster access
- PostgreSQL: Schema deployment role + workload user credentials
- Three Tier Web App: Aggregates and manages all credentials automatically
