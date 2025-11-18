# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a three-tier web application demonstrating Infrastructure Deployment Platform (IDP) capabilities through composable products and reference applications.

## Repository Structure

```
hello-world/
├── products/                    # IDP Products (composable infrastructure)
│   └── k8s-cluster/
│       └── local/              # Local Kubernetes using kind (Kubernetes in Docker)
├── examples/                   # Reference Applications
│   └── baby-names/             # Three-tier web application (COMPLETE)
└── scripts/                    # Setup and utility scripts
```

## Completed Components

### IDP Products

#### K8s Cluster (Local Variant)
- **Location**: `products/k8s-cluster/local/`
- **Technology**: kind (Kubernetes in Docker)
- **Status**: ✅ Complete
- **Description**: Terraform-managed local Kubernetes cluster for development
- **Key Features**:
  - Configurable worker nodes
  - Port mappings for ingress
  - Namespace and service account creation
  - Generates both admin and service account kubeconfigs

**Usage**:
```bash
cd products/k8s-cluster/local
terraform init
terraform apply
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

### Reference Applications

#### Baby Names Rank Finder
- **Location**: `examples/baby-names/`
- **Status**: ✅ Complete with production-ready CI/CD
- **Description**: Three-tier application using 2024 ONS baby names data with comprehensive security scanning and supply chain attestations

**Architecture**:
```
Frontend (Flask) :8080
    ↓
Backend API (Flask) :5000
    ↓
PostgreSQL :5432
```

**Components**:
- **Frontend**: Flask web app (Alpine-based, Python 3.11)
- **Backend**: REST API with `/api/v1/names` endpoints (Alpine-based, Python 3.11)
- **Database**: PostgreSQL 15 with Liquibase migrations
- **Data**: Real 2024 ONS boys' baby names dataset (50 names)
- **CI/CD**: Three-phase pipeline with Makefile orchestration

**Container Security**:
- Alpine Linux base images (zero CRITICAL vulnerabilities)
- SBOM attestation (SPDX format via Syft)
- Vulnerability scanning (Trivy)
- Build provenance attestation

**Quick Start**:
```bash
cd examples/baby-names

# Set Docker socket for Podman (WSL2)
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock

# Start all services
docker-compose up -d

# Test the application
curl http://localhost:8080/?name=Noah
curl http://localhost:5000/api/v1/names/Muhammad

# Stop services
docker-compose down -v
```

**Local CI/CD Execution**:
```bash
cd examples/baby-names

# Add required tools to PATH
export PATH="$HOME/.local/bin:$PATH"

# Run Phase A (quality gates)
make phase-a  # Format check, lint, security scan, unit tests

# Run Phase B (container operations)
make phase-b  # Build, SBOM generation, vulnerability scan

# Run complete CI pipeline
make ci-local  # Executes both phases sequentially

# Component-specific operations
cd backend
make format-check  # Check code formatting
make lint         # Run linting
make security-check  # Dependency vulnerability scan
make test         # Run unit tests with coverage
make build        # Build container
make generate-sbom  # Generate SBOM
make scan         # Scan for vulnerabilities
```

**Testing**:
```bash
# Backend unit tests (14 tests, 93% coverage)
cd examples/baby-names/backend
pytest tests/ -v --cov=. --cov-report=term

# Frontend unit tests (7 tests, 99% coverage)
cd examples/baby-names/frontend
pytest tests/ -v --cov=. --cov-report=term

# All tests run without requiring live database
# Database connections are mocked via tests/conftest.py
```

## CI/CD Pipelines

### CI Pipeline (`.github/workflows/ci.yml`)

Three-phase pipeline with comprehensive attestations:

**Phase A - Sequential Quality Gates (Fail-Fast)**:
1. **Format & Lint** (backend, frontend)
   - Ruff formatting check
   - Ruff linting
   - Generates and attests lint results
2. **Dependency Security** (backend, frontend)
   - Safety vulnerability scan
   - Fails on CRITICAL vulnerabilities only
   - Generates and attests security reports
3. **Unit Tests** (backend, frontend)
   - Pytest with coverage reporting
   - 93% backend coverage, 99% frontend coverage
   - Generates and attests coverage reports

**Phase B - Parallel Build & Scan** (backend, frontend, db-migration):
1. **Build**: Container image using Makefiles
2. **SBOM Generation**: Syft (SPDX format)
3. **Vulnerability Scan**: Trivy (CRITICAL severity)
4. **Attestations**:
   - SBOM attestation
   - Scan results attestation
   - Build provenance attestation
5. **Push**: Registry push (non-PR only)
6. **Job Summary**: Outputs container details (registry URL, digest) to GitHub Actions job summary

**Phase C - Integration Tests**:
1. **Service Deployment**: Start full stack with docker-compose
2. **Health Checks**: Verify backend and frontend endpoints
3. **Integration Testing**: Run pytest integration test suite
4. **Cleanup**: Tear down docker-compose services

**Key Features**:
- All commands delegated to Makefiles for consistency
- Local execution: `make ci-local`
- GitHub Actions attestations for supply chain security
- Alpine-based images with zero CRITICAL CVEs
- Artifacts: lint results, security reports, coverage, SBOMs, scan results

**Required Tools** (auto-installed in CI, manual for local):
- Ruff 0.8.4 (linting/formatting)
- Safety 2.3.5 (dependency scanning)
- Syft (SBOM generation)
- Trivy (container scanning)

## Environment Setup

### Prerequisites
- Docker/Podman
- Python 3.11+
- Terraform 1.5+ (for k8s-cluster product)
- kubectl (for k8s-cluster product)

### Local CI Tools (Optional)
For running the full CI pipeline locally:
```bash
# Install Syft (SBOM generation)
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/.local/bin

# Install Trivy (vulnerability scanning)
curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ~/.local/bin

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Python tools (ruff, safety) are auto-installed by Makefiles
```

### Podman Configuration (WSL2)

If using Podman instead of Docker:

1. **Configure registry search**:
```bash
sudo tee /etc/containers/registries.conf.d/00-unqualified-search-registries.conf > /dev/null <<EOF
unqualified-search-registries = ["docker.io"]
EOF
```

2. **Set Docker socket environment variable**:
```bash
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
# Add to ~/.bashrc for persistence
```

3. **Verify setup**:
```bash
docker --version  # Should show: podman version X.X.X
docker ps
```

## Development Workflow

### Three-Tier Architecture Pattern

All applications follow this structure:
- **Presentation Layer**: UI/frontend components (Flask, HTML templates)
- **Application Layer**: Business logic and API endpoints (Flask REST API)
- **Data Layer**: Database interactions (PostgreSQL, Liquibase)

### Adding New Applications

1. Create directory under `examples/`
2. Implement three tiers with clear separation
3. Add `docker-compose.yml` for local development
4. Create comprehensive tests (unit, integration, smoke)
5. Add CI/CD workflows
6. Document in README.md

### Working with IDP Products

IDP products are composable infrastructure components:
- Each product has variants (e.g., `local`, `gcp`, `aws`)
- Managed with Terraform
- Outputs can be consumed by other products or applications
- Follow the existing structure in `products/k8s-cluster/`

## Known Issues and Fixes

### Podman on WSL2

**Issue**: Docker commands fail with permission denied
**Solution**: Set `DOCKER_HOST` environment variable:
```bash
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
```

**Issue**: Unqualified image names not found
**Solution**: Configure `/etc/containers/registries.conf.d/00-unqualified-search-registries.conf`

### Database Migrations

**Issue**: PostgreSQL COPY command fails in containerized environments
**Solution**: Use INSERT statements instead of COPY FROM for CSV data loading

## Future Development

### Planned IDP Products
- PostgreSQL Database product (managed database instances)
- Three Tier Web App product (deployment template)
- Ingress/Load Balancer product
- Monitoring/Observability product

### Planned Applications
- Additional reference applications demonstrating different patterns
- Integration examples with various IDP products
- Production-ready deployment configurations

## Documentation

- Project README: `README.md`
- Baby Names App: `examples/baby-names/README.md`
- Each IDP product includes its own README with usage instructions

## Contributing

### REQUIRED: Update CHANGELOG Before Commit

**Every commit MUST include CHANGELOG updates** following [Keep a Changelog v1.1.0](https://keepachangelog.com/en/1.1.0/) format.

For the baby-names application, update `examples/baby-names/CHANGELOG.md`:

1. **Add entries under `[Unreleased]` section** in the appropriate category:
   - **Added**: New features
   - **Changed**: Changes to existing functionality
   - **Deprecated**: Soon-to-be removed features
   - **Removed**: Removed features
   - **Fixed**: Bug fixes
   - **Security**: Security improvements

2. **Format**: Use present tense, be specific
   ```markdown
   ### Added
   - New `/api/v2/names` endpoint with pagination support

   ### Fixed
   - Database connection pool exhaustion under high load
   ```

3. **Before Release**: Move `[Unreleased]` items to a new version section with date

**Why**: CHANGELOGs provide:
- Clear history of what changed and why
- Easy communication with users and team members
- Foundation for release notes
- Audit trail for compliance

### Development Workflow

When working on this repository:
1. **Update CHANGELOG.md first** - Document what you're about to change
2. Test locally with docker-compose before committing
3. Run CI pipeline locally: `cd examples/baby-names && make ci-local`
4. Or run individual checks:
   - Format code: `make format`
   - Check formatting: `make format-check`
   - Lint code: `make lint`
   - Security scan: `make security-check`
   - Run tests: `make test`
5. Ensure all tests pass (21 total tests, 93%+ coverage)
6. Update other documentation if needed (CLAUDE.md, README.md)
7. Follow the three-tier architecture pattern for applications
8. Use Terraform for all infrastructure code
9. Use Alpine-based container images for minimal attack surface
