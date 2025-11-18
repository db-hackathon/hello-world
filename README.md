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

### CI/CD Pipeline Architecture

Location: `/.github/workflows/ci.yml`

**Two-Phase Pipeline with Fail-Fast Quality Gates:**

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
