# Changelog

All notable changes to the Baby Names application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive three-phase CI pipeline with fail-fast quality gates
  - Phase A: Sequential quality checks (format, lint, security, tests)
  - Phase B: Parallel container build, scan, and attestation
  - Phase C: Integration tests with docker-compose deployment
- Container details output to GitHub Actions job summary
  - Each build job outputs registry URL and digest
  - Includes both short and full digest for easy verification
  - Links to attestation artifacts
- Integration tests integrated into CI pipeline
  - Moved from CD to CI workflow for earlier feedback
  - Tests full application stack with docker-compose
  - Includes service health checks before testing
  - Comprehensive logging on failure
- Helm chart for Kubernetes deployment (`helm/baby-names/`)
  - Separate templates for namespace, serviceaccount, deployments, services, ingress
  - Cloud SQL Proxy sidecar for IAM database authentication
  - Helm hooks for pre-install/pre-upgrade database migrations
  - Environment-specific values files (values.yaml, values-staging.yaml)
  - Support for both IAM and password-based authentication
- GKE deployment via CD workflow
  - Direct Workload Identity Federation (WIF) for GitHub Actions authentication
  - Helm-based deployment to GKE cluster
  - Automated database migrations via Helm hooks
  - Health verification after deployment
- Smoke tests for deployed staging environment
  - Frontend and backend health endpoint verification
  - Database connectivity validation
  - Critical user path testing (name lookup)
- IAM database authentication support
  - Backend modified to support passwordless IAM authentication
  - Cloud SQL Proxy sidecar handles IAM token generation
  - Maintains backward compatibility with password-based auth
  - Liquibase migrations support IAM authentication
- Makefile-based build system for local and CI execution
  - Root Makefile for orchestrating multi-component builds
  - Component-level Makefiles (backend, frontend, database)
  - Support for Phase A (`make phase-a`) and Phase B (`make phase-b`) execution
- Code quality tooling
  - Ruff 0.8.4 for Python linting and formatting
  - Configured with project-specific rules in `ruff.toml`
- Security scanning infrastructure
  - Safety 2.3.5 for Python dependency vulnerability scanning
  - `.safety-policy.yml` for CRITICAL-only filtering in CI
  - Syft for SBOM generation (SPDX format)
  - Trivy for container vulnerability scanning
- Supply chain security with GitHub Actions attestations
  - Lint results attestation
  - Security scan results attestation
  - Test coverage attestation
  - Container SBOM attestation
  - Container vulnerability scan attestation
  - Build provenance attestation
- Test infrastructure improvements
  - Backend test fixtures with database connection mocking (`tests/conftest.py`)
  - 93% code coverage for backend (14 tests)
  - 99% code coverage for frontend (7 tests)
  - All tests runnable without live database connection

### Changed
- **BREAKING**: Migrated from Debian to Alpine Linux base images
  - Backend: `python:3.11-alpine` (from `python:3.11-slim`)
  - Frontend: `python:3.11-alpine` (from `python:3.11-slim`)
  - Eliminates 3 CRITICAL CVEs present in Debian base images
  - Zero CRITICAL vulnerabilities in Alpine-based containers
- Updated Python dependencies
  - Flask 3.0.0 → 3.1.0
  - flask-cors 4.0.0 → 6.0.0
  - requests 2.31.0 → 2.32.4
- Replaced Flake8 and Black with Ruff for unified linting/formatting
- GitHub Actions CI workflow now delegates to Makefiles
  - Consistent behavior between local and CI environments
  - Single source of truth for build/test/scan commands
- CD workflow now performs actual GKE deployment
  - Uses Direct Workload Identity Federation instead of service account keys
  - Deploys to manually provisioned GKE cluster and CloudSQL instance
  - Integration tests moved to CI pipeline for earlier feedback
  - Smoke tests verify deployed application health
  - Clearer separation: CI validates, CD deploys
- Database connection handling in backend
  - Fixed psycopg2.pool import for proper connection pooling
  - Uses `from psycopg2 import pool` instead of `psycopg2.pool`
  - Added IAM authentication support via `DB_IAM_AUTH` environment variable
  - Conditionally omits password when IAM auth is enabled
- Frontend error handling
  - Test suite now uses `requests.exceptions.ConnectionError` instead of generic Exception

### Fixed
- Unit tests no longer require running PostgreSQL instance
- Import sorting issues detected by Ruff
- Module-level database instantiation now properly mocked during tests
- Configuration files (`.safety-policy.yml`, `ruff.toml`) moved to correct location under `examples/baby-names/`
- Helm deployment ordering issue where migration job couldn't find service account
  - Removed Helm hooks from migration job to allow regular resource creation order
  - Added init containers to backend/frontend to wait for migration completion
  - Ensures service account exists before migration job attempts to use it
- Container image paths in Helm values.yaml missing repository path component
  - Fixed backend image path: `ghcr.io/db-hackathon/hello-world/baby-names-backend`
  - Fixed frontend image path: `ghcr.io/db-hackathon/hello-world/baby-names-frontend`
  - Fixed migration image path: `ghcr.io/db-hackathon/hello-world/baby-names-db-migration`
  - Aligns with CI workflow image naming convention using `${{ github.repository }}`
- Helm deployment failure due to namespace creation conflict
  - Removed `--create-namespace` flag from CD workflow helm command
  - Namespace now managed exclusively through Helm template (templates/namespace.yaml)
  - Prevents "namespace already exists" error when Helm template and flag both try to create namespace

### Security
- Container images now scan clean for CRITICAL vulnerabilities
- Dependency vulnerability scanning integrated into CI pipeline
- All security artifacts attested via GitHub Actions
- SBOM generated for all containers (backend, frontend, db-migration)
- IAM-based authentication for database access (no passwords in production)
  - Uses Google Cloud IAM for CloudSQL authentication
  - Cloud SQL Proxy handles automatic token refresh
  - GKE Workload Identity links Kubernetes service accounts to GCP service accounts
- Direct Workload Identity Federation for GitHub Actions
  - No long-lived service account keys required
  - GitHub OIDC tokens provide short-lived access to GCP
  - Principle of least privilege via precise IAM bindings
