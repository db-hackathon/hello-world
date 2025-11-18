# Baby Names Application CI Makefile
# Delegates to component-level Makefiles (backend, frontend, database)

.PHONY: help lint format-check security-check test phase-a
.PHONY: build-all scan-all generate-sbom-all phase-b ci-local clean

# Default target
help:
	@echo "Baby Names CI Makefile"
	@echo ""
	@echo "Phase A (Sequential, Fail-Fast):"
	@echo "  make lint              - Run linting (ruff check)"
	@echo "  make format-check      - Check code formatting (ruff format --check)"
	@echo "  make security-check    - Run dependency security scan (safety)"
	@echo "  make test              - Run unit tests (pytest)"
	@echo "  make phase-a           - Run all Phase A steps"
	@echo ""
	@echo "Phase B (Parallel Build & Scan):"
	@echo "  make build-all         - Build all container images"
	@echo "  make scan-all          - Scan all container images for vulnerabilities"
	@echo "  make generate-sbom-all - Generate SBOMs for all containers"
	@echo "  make phase-b           - Run all Phase B steps"
	@echo ""
	@echo "Full CI:"
	@echo "  make ci-local          - Run complete CI pipeline locally"
	@echo "  make clean             - Clean build artifacts"

##
## PHASE A - Sequential Quality Gates
##

lint:
	@echo "==> Running lint checks..."
	@$(MAKE) -C backend lint
	@$(MAKE) -C frontend lint
	@echo "==> Lint checks passed!"

format-check:
	@echo "==> Checking code formatting..."
	@$(MAKE) -C backend format-check
	@$(MAKE) -C frontend format-check
	@echo "==> Format checks passed!"

security-check:
	@echo "==> Running dependency security scans..."
	@$(MAKE) -C backend security-check
	@$(MAKE) -C frontend security-check
	@echo "==> Security scans passed!"

test:
	@echo "==> Running unit tests..."
	@$(MAKE) -C backend test
	@$(MAKE) -C frontend test
	@echo "==> Unit tests passed!"

# Phase A runs all steps sequentially
phase-a: format-check lint security-check test
	@echo "==> Phase A complete!"

##
## PHASE B - Build, Scan, Attest
##

build-all:
	@echo "==> Building all container images..."
	@$(MAKE) -C backend build
	@$(MAKE) -C frontend build
	@$(MAKE) -C database build
	@echo "==> All images built!"

generate-sbom-all:
	@echo "==> Generating SBOMs for all containers..."
	@$(MAKE) -C backend generate-sbom
	@$(MAKE) -C frontend generate-sbom
	@$(MAKE) -C database generate-sbom
	@echo "==> All SBOMs generated!"

scan-all:
	@echo "==> Scanning all container images..."
	@$(MAKE) -C backend scan
	@$(MAKE) -C frontend scan
	@$(MAKE) -C database scan
	@echo "==> All scans passed!"

# Phase B runs build, SBOM generation, and scan
phase-b: build-all generate-sbom-all scan-all
	@echo "==> Phase B complete!"

##
## Full CI Pipeline
##

ci-local: phase-a phase-b
	@echo ""
	@echo "======================================"
	@echo "  CI Pipeline Completed Successfully!"
	@echo "======================================"
	@echo ""
	@echo "Phase A: ✓ Format, Lint, Security, Tests"
	@echo "Phase B: ✓ Build, SBOM, Scan"
	@echo ""

##
## Utility Targets
##

clean:
	@echo "==> Cleaning build artifacts..."
	@$(MAKE) -C backend clean
	@$(MAKE) -C frontend clean
	@$(MAKE) -C database clean
	@echo "==> Clean complete!"
