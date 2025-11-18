# Changelog

All notable changes to the Baby Names application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive two-phase CI pipeline with fail-fast quality gates
  - Phase A: Sequential quality checks (format, lint, security, tests)
  - Phase B: Parallel container build, scan, and attestation
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
- Database connection handling in backend
  - Fixed psycopg2.pool import for proper connection pooling
  - Uses `from psycopg2 import pool` instead of `psycopg2.pool`
- Frontend error handling
  - Test suite now uses `requests.exceptions.ConnectionError` instead of generic Exception

### Fixed
- Unit tests no longer require running PostgreSQL instance
- Import sorting issues detected by Ruff
- Module-level database instantiation now properly mocked during tests
- Configuration files (`.safety-policy.yml`, `ruff.toml`) moved to correct location under `examples/baby-names/`

### Security
- Container images now scan clean for CRITICAL vulnerabilities
- Dependency vulnerability scanning integrated into CI pipeline
- All security artifacts attested via GitHub Actions
- SBOM generated for all containers (backend, frontend, db-migration)
