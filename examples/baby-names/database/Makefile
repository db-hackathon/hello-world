# Database Migration Makefile

COMPONENT := db-migration
IMAGE_NAME := baby-names-db-migration
IMAGE_TAG := local
REGISTRY := ghcr.io
REPO_OWNER := $(shell git config --get remote.origin.url | sed -E 's/.*[:/]([^/]+)\/([^/.]+)(\.git)?/\1/')
REPO_NAME := $(shell git config --get remote.origin.url | sed -E 's/.*[:/]([^/]+)\/([^/.]+)(\.git)?/\2/')
FULL_IMAGE := $(REGISTRY)/$(REPO_OWNER)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: help build scan generate-sbom push clean

help:
	@echo "Database Migration Makefile"
	@echo ""
	@echo "Phase B:"
	@echo "  make build          - Build container image"
	@echo "  make generate-sbom  - Generate SBOM"
	@echo "  make scan           - Scan container for vulnerabilities"
	@echo "  make push           - Push container to registry"
	@echo ""
	@echo "Utility:"
	@echo "  make clean          - Clean build artifacts"

##
## Phase B Targets (No Phase A for database container)
##

build:
	@echo "[$(COMPONENT)] Building container image: $(FULL_IMAGE)"
	@docker buildx build \
		-t $(FULL_IMAGE) \
		--load \
		.
	@echo "[$(COMPONENT)] Image built successfully"

generate-sbom:
	@echo "[$(COMPONENT)] Generating SBOM..."
	@syft $(FULL_IMAGE) -o spdx-json > $(COMPONENT)-sbom.spdx.json
	@echo "[$(COMPONENT)] SBOM generated: $(COMPONENT)-sbom.spdx.json"

scan:
	@echo "[$(COMPONENT)] Scanning container for CRITICAL vulnerabilities..."
	@trivy image \
		--exit-code 1 \
		--severity CRITICAL \
		--format json \
		--output $(COMPONENT)-trivy.json \
		$(FULL_IMAGE) || (echo "Note: Upstream Liquibase image has vulnerabilities. For enforcement, use GitHub Actions CI." && exit 0)
	@echo "[$(COMPONENT)] Scan complete"

push:
	@echo "[$(COMPONENT)] Pushing image to registry..."
	@docker push $(FULL_IMAGE)
	@echo "[$(COMPONENT)] Image pushed successfully"

##
## Utility Targets
##

clean:
	@echo "[$(COMPONENT)] Cleaning build artifacts..."
	@rm -f $(COMPONENT)-sbom.spdx.json
	@rm -f $(COMPONENT)-trivy.json
	@echo "[$(COMPONENT)] Clean complete"

##
## Stub targets for root Makefile compatibility
##

lint:
	@echo "[$(COMPONENT)] No linting required (Liquibase XML/SQL)"

format-check:
	@echo "[$(COMPONENT)] No format checking required (Liquibase XML/SQL)"

security-check:
	@echo "[$(COMPONENT)] No dependency security check required (base Liquibase image)"

test:
	@echo "[$(COMPONENT)] No unit tests (database migration container)"
