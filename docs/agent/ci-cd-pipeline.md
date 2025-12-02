# CI/CD Pipeline Reference

This document provides detailed CI/CD pipeline information for Claude Code.

## Local CI Execution

```bash
cd examples/baby-names
export PATH="$HOME/.local/bin:$PATH"

# Run complete CI pipeline
make ci-local

# Or run phases separately
make phase-a  # Format check, lint, security scan, unit tests
make phase-b  # Build, SBOM generation, vulnerability scan
```

## CI Pipeline (`.github/workflows/ci.yml`)

Three-phase pipeline with comprehensive attestations.

### Phase A - Sequential Quality Gates (Fail-Fast)

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

### Phase B - Parallel Build & Scan

Components: backend, frontend, db-migration

1. **Build**: Container image using Makefiles
2. **SBOM Generation**: Syft (SPDX format)
3. **Vulnerability Scan**: Trivy (CRITICAL severity)
4. **Attestations**: SBOM, scan results, build provenance
5. **Push**: Registry push (non-PR only)
6. **Job Summary**: Container details to GitHub Actions job summary

### Phase C - Integration Tests

1. **Service Deployment**: Start full stack with docker-compose
2. **Health Checks**: Verify backend and frontend endpoints
3. **Integration Testing**: Run pytest integration test suite
4. **Cleanup**: Tear down docker-compose services

### Key Features

- All commands delegated to Makefiles for consistency
- GitHub Actions attestations for supply chain security
- Alpine-based images with zero CRITICAL CVEs
- Artifacts: lint results, security reports, coverage, SBOMs, scan results

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Ruff | 0.8.4 | Linting/formatting |
| Safety | 2.3.5 | Dependency scanning |
| Syft | latest | SBOM generation |
| Trivy | latest | Container scanning |

## CD Pipeline (`.github/workflows/cd.yml`)

### Triggers

- **Automatic**: After CI workflow completes successfully on `main` branch
- **Manual**: Via `workflow_dispatch` with commit SHA, environment, dry-run inputs

### Manual Deployment

```bash
# Dry-run: validate images exist without deploying
gh workflow run cd.yml \
  --field commit_sha=<full-40-char-sha> \
  --field environment=staging \
  --field dry_run=true

# Actual deployment to staging
gh workflow run cd.yml \
  --field commit_sha=<full-40-char-sha> \
  --field environment=staging \
  --field dry_run=false
```

### Workflow Jobs

1. **resolve-sha**: Determines deployment SHA, validates images exist
2. **deploy-staging**: Deploys to GKE staging (automatic after CI or manual)
3. **smoke-tests-staging**: Verifies deployment health
4. **deploy-production**: Production deployment (manual only, stubbed)
5. **smoke-tests-production**: Production health verification (stubbed)

### Deployment Process

1. **Authentication**: Direct Workload Identity Federation (WIF) to GCP
2. **GKE Access**: Install gke-gcloud-auth-plugin, get cluster credentials
3. **Helm Deployment**: Deploy with `values-staging.yaml` and short SHA tag
4. **Health Verification**: Check pod, service, ingress status
5. **Smoke Tests**: Frontend health, backend health, critical user path

### Security Features

- **Direct WIF**: Short-lived GitHub OIDC tokens, no long-lived credentials
- **IAM Database Auth**: CloudSQL authentication via service account identity
- **Workload Identity**: Bound to Kubernetes service account
- **Cloud SQL Proxy**: Automatic IAM token refresh

### Attestation Chain Architecture

The CI/CD pipeline implements a comprehensive attestation chain that proves supply chain integrity without requiring artifact downloads during deployment.

#### Enhanced SBOM with Quality Gate Hashes

Quality gate artifact hashes are embedded directly into the SBOM before attestation:

```
┌─────────────────────────────────────────────────────────────┐
│                    Enhanced SBOM (SPDX)                      │
│  {                                                           │
│    "spdxVersion": "SPDX-2.3",                               │
│    "packages": [...],  // Software inventory                 │
│    "annotations": [{                                         │
│      "annotationType": "OTHER",                             │
│      "annotator": "Tool: baby-names-ci-pipeline",           │
│      "comment": "quality_gates={                            │
│        lint: sha256:abc...,                                 │
│        safety: sha256:def...,                               │
│        coverage: sha256:ghi...,                             │
│        trivy: sha256:jkl...                                 │
│      };git_sha=...;run_id=..."                              │
│    }]                                                        │
│  }                                                           │
└─────────────────────────────────────────────────────────────┘
```

#### Verification Sequence

For each component (backend, frontend, db-migration):

1. **Build Provenance** (`https://slsa.dev/provenance/v1`)
   - Proves CI pipeline identity (GitHub Actions)
   - Links container to specific git SHA

2. **Enhanced SBOM** (`https://spdx.dev/Document`)
   - Proves software composition (package inventory)
   - Proves quality gates passed (embedded hashes)
   - Single attestation contains all quality evidence

3. **Git SHA Validation**
   - Extracts SHA from Build Provenance certificate
   - Compares against deployment target SHA
   - Proves deployed code = source code

#### Supply Chain Security Properties

| Property | Attestation | How It's Proven |
|----------|-------------|-----------------|
| Code passed linting | Enhanced SBOM | SHA256 of lint-results.json in annotation |
| Code passed security scan | Enhanced SBOM | SHA256 of safety-report.json in annotation |
| Code passed tests | Enhanced SBOM | SHA256 of coverage.xml in annotation |
| Container scanned | Enhanced SBOM | SHA256 of trivy.json in annotation |
| Built by trusted CI | Build Provenance | SLSA v1 provenance |
| Software inventory known | Enhanced SBOM | SPDX packages list |
| Same code deployed | Git SHA validation | SHA in provenance matches target |

#### Key Benefits

- **GitHub Native**: Uses only `actions/attest-sbom` and `actions/attest-build-provenance`
- **Single Download**: CD only queries attestations, no artifact downloads needed
- **Tamper-Proof**: Quality gate hashes are inside the attested SBOM content
- **Backward Compatible**: Older SBOMs without annotations still pass (with warning)
