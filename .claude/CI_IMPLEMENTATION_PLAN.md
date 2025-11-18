# CI Implementation Plan

**Created**: 2025-11-17
**Status**: Approved - Ready for Implementation

## Overview
Implement a two-phase CI pipeline with fail-fast behavior, comprehensive attestations, and local executability.

## User Requirements

### Phase A (Sequential, Fail-Fast)
1. Formatting & linting with ruff
2. Dependency vulnerability check with safety
3. Assert no CRITICAL vulnerabilities
4. Execute unit tests

### Phase B (Parallel for backend, frontend, db-migration)
1. Build container image
2. Scan container image for vulnerabilities
3. Assert no CRITICAL vulnerabilities
4. Push container to registry

### Requirements
- Each phase must generate attestations using GitHub Actions attestations
- Each container must have an attested SBOM
- Build steps should be locally executable where possible
- Attestations can only run in GitHub Actions

### User Decisions
- **Phase A Attestations**: Attest result artifacts (coverage.xml, safety-report.json, etc.)
- **Components to Build**: backend, frontend, db-migration
- **SBOM Tool**: Syft (standalone tool)
- **Makefile Structure**: Both levels (root + component-level)

## Files to Create/Modify

### New Files to Create

1. **`.safety-policy.yml`** (repository root)
   - Safety configuration to fail only on CRITICAL vulnerabilities

2. **`ruff.toml`** (repository root)
   - Ruff linter/formatter configuration for Python 3.11

3. **`examples/baby-names/Makefile`**
   - Baby names application Makefile that orchestrates all CI tasks
   - Delegates to component-level Makefiles (backend, frontend, database)

4. **`examples/baby-names/backend/Makefile`**
   - Backend-specific build, test, scan commands

5. **`examples/baby-names/frontend/Makefile`**
   - Frontend-specific build, test, scan commands

6. **`examples/baby-names/database/Makefile`**
   - Database migration container build and scan commands

7. **`.github/workflows/ci.yml`** (replace existing)
   - New CI workflow implementing Phase A and Phase B
   - Sequential Phase A jobs with fail-fast
   - Parallel Phase B jobs with attestations

### Files to Update

8. **`examples/baby-names/backend/requirements.txt`**
   - Add: ruff, safety

9. **`examples/baby-names/frontend/requirements.txt`**
   - Add: ruff, safety

10. **`examples/baby-names/README.md`**
    - Add section on running CI locally with Make
    - Document attestation verification

## Phase A Implementation (Sequential, Fail-Fast)

### Job 1: format-and-lint
- Run `ruff format --check` for backend and frontend
- Run `ruff check` for backend and frontend
- Generate lint-results.json artifact
- Attest lint-results.json
- **Locally executable**: `make lint`

### Job 2: dependency-security (needs: format-and-lint)
- Install dependencies for backend and frontend
- Run `safety scan` for backend (with .safety-policy.yml)
- Run `safety scan` for frontend (with .safety-policy.yml)
- Fail if CRITICAL vulnerabilities found
- Generate safety-report.json artifacts
- Attest safety-report.json for each component
- **Locally executable**: `make security-check`

### Job 3: unit-tests (needs: dependency-security)
- Run pytest for backend with coverage
- Run pytest for frontend with coverage
- Generate coverage.xml artifacts
- Attest coverage.xml for each component
- Upload coverage to Codecov (optional)
- **Locally executable**: `make test`

## Phase B Implementation (Parallel, After Phase A)

### Job Matrix: build-scan-attest (needs: unit-tests)
**Matrix**: component: [backend, frontend, db-migration]

For each component:

1. **Build container image** (locally, don't push)
   - `docker buildx build -t ghcr.io/$REPO/baby-names-$COMPONENT:$TAG`
   - Capture image digest

2. **Generate SBOM with Syft**
   - `syft ghcr.io/$REPO/baby-names-$COMPONENT:$TAG -o spdx-json > $COMPONENT-sbom.spdx.json`

3. **Scan container with Trivy**
   - `trivy image --exit-code 1 --severity CRITICAL --format json --output $COMPONENT-trivy.json`
   - Fail if CRITICAL vulnerabilities found

4. **Attest SBOM** (GitHub Actions only)
   - Use `actions/attest-sbom@v3`
   - Subject: container image with digest
   - SBOM path: $COMPONENT-sbom.spdx.json

5. **Attest Build Provenance** (GitHub Actions only)
   - Use `actions/attest-build-provenance@v3`
   - Subject: container image with digest
   - Includes build workflow, inputs, dependencies

6. **Push container to registry**
   - `docker push ghcr.io/$REPO/baby-names-$COMPONENT:$TAG`
   - Only on successful scans

**Locally executable**: `make build-backend`, `make scan-backend`, etc.

## Makefile Structure

### Baby Names Makefile (`examples/baby-names/Makefile`)
```makefile
# Delegates to component Makefiles
# Provides top-level targets: phase-a, phase-b, ci-local

.PHONY: lint security-check test phase-a
.PHONY: build-all scan-all phase-b ci-local

# Phase A targets
lint:
    @$(MAKE) -C backend lint
    @$(MAKE) -C frontend lint

security-check:
    @$(MAKE) -C backend security-check
    @$(MAKE) -C frontend security-check

test:
    @$(MAKE) -C backend test
    @$(MAKE) -C frontend test

phase-a: lint security-check test

# Phase B targets
build-all:
    @$(MAKE) -C backend build
    @$(MAKE) -C frontend build
    @$(MAKE) -C database build

scan-all:
    @$(MAKE) -C backend scan
    @$(MAKE) -C frontend scan
    @$(MAKE) -C database scan

phase-b: build-all scan-all

# Full local CI
ci-local: phase-a phase-b
```

### Component Makefiles (backend/Makefile, frontend/Makefile, database/Makefile)
Each component Makefile includes:
- `lint`: Run ruff format check + ruff check
- `security-check`: Run safety scan
- `test`: Run pytest with coverage
- `build`: Build Docker image locally
- `scan`: Scan image with Trivy
- `generate-sbom`: Generate SBOM with Syft

## GitHub Actions Workflow Structure

```yaml
name: CI

on: [push, pull_request]

permissions:
  contents: read
  packages: write
  id-token: write       # Required for attestations
  attestations: write   # Required for attestations
  security-events: write

jobs:
  # PHASE A - Sequential, fail-fast

  format-and-lint:
    runs-on: ubuntu-latest
    steps:
      - checkout
      - install ruff
      - run: make lint
      - save lint-results.json
      - attest lint-results.json

  dependency-security:
    needs: format-and-lint
    runs-on: ubuntu-latest
    strategy:
      matrix:
        component: [backend, frontend]
    steps:
      - checkout
      - install dependencies
      - run: make security-check
      - save safety-report.json
      - attest safety-report.json

  unit-tests:
    needs: dependency-security
    runs-on: ubuntu-latest
    strategy:
      matrix:
        component: [backend, frontend]
    steps:
      - checkout
      - run: make test
      - save coverage.xml
      - attest coverage.xml
      - upload to Codecov

  # PHASE B - Parallel, after Phase A completes

  build-scan-attest:
    needs: unit-tests
    runs-on: ubuntu-latest
    strategy:
      fail-fast: true
      matrix:
        component: [backend, frontend, db-migration]
    steps:
      - checkout
      - setup buildx
      - login to ghcr.io
      - build image (get digest)
      - install syft
      - generate SBOM
      - scan with trivy (fail on CRITICAL)
      - attest SBOM
      - attest build provenance
      - push image to registry
```

## Configuration Files

### `.safety-policy.yml`
```yaml
security:
  fail-scan-with-exit-code:
    dependency-vulnerabilities:
      enabled: true
      cvss-severity:
        - critical
        - unknown  # Catch unscored CVEs
```

### `ruff.toml`
```toml
line-length = 127
target-version = "py311"

[lint]
select = [
    "E",   # pycodestyle errors
    "W",   # pycodestyle warnings
    "F",   # pyflakes
    "I",   # isort
    "B",   # flake8-bugbear
    "C4",  # flake8-comprehensions
]

[format]
quote-style = "double"
indent-style = "space"
```

## Implementation Steps

1. Create configuration files (.safety-policy.yml, ruff.toml)
2. Create baby-names Makefile (examples/baby-names/Makefile)
3. Create component Makefiles (backend, frontend, database)
4. Update requirements.txt files
5. Replace .github/workflows/ci.yml
6. Update documentation
7. Test locally
8. Test in GitHub Actions

## Success Criteria

- ✅ Phase A runs sequentially (lint → security → tests)
- ✅ Phase A fails fast (any failure stops pipeline)
- ✅ Phase B runs in parallel for all three components
- ✅ CRITICAL vulnerabilities fail the build
- ✅ All result artifacts are attested (lint, security, coverage)
- ✅ All containers have SBOM attestations
- ✅ All containers have build provenance attestations
- ✅ >90% of CI is locally executable via Makefile
- ✅ Attestations are verifiable with `gh attestation verify`
