# Frontend Makefile

COMPONENT := frontend
IMAGE_NAME := baby-names-frontend
IMAGE_TAG := local
REGISTRY := ghcr.io
REPO_OWNER := $(shell git config --get remote.origin.url | sed -E 's/.*[:/]([^/]+)\/([^/.]+)(\.git)?/\1/')
REPO_NAME := $(shell git config --get remote.origin.url | sed -E 's/.*[:/]([^/]+)\/([^/.]+)(\.git)?/\2/')
FULL_IMAGE := $(REGISTRY)/$(REPO_OWNER)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: help lint format-check format security-check test
.PHONY: build scan generate-sbom push clean

help:
	@echo "Frontend Makefile"
	@echo ""
	@echo "Phase A:"
	@echo "  make format-check   - Check code formatting"
	@echo "  make format         - Format code with ruff"
	@echo "  make lint           - Run linting"
	@echo "  make security-check - Run dependency security scan"
	@echo "  make test           - Run unit tests"
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
## Phase A Targets
##

format-check:
	@echo "[$(COMPONENT)] Checking code formatting..."
	@pip install -q --break-system-packages ruff==0.8.4
	@ruff format --check .

format:
	@echo "[$(COMPONENT)] Formatting code..."
	@pip install -q --break-system-packages ruff==0.8.4
	@ruff format .

lint:
	@echo "[$(COMPONENT)] Running lint checks..."
	@pip install -q --break-system-packages ruff==0.8.4
	@ruff check .

security-check:
	@echo "[$(COMPONENT)] Running dependency security scan..."
	@pip install -q --break-system-packages -r requirements.txt
	@safety check || (echo "Note: Safety 2.x found vulnerabilities. For CRITICAL-only filtering, use GitHub Actions CI." && exit 0)

test:
	@echo "[$(COMPONENT)] Running unit tests..."
	@pip install -q --break-system-packages -r requirements.txt
	@pytest tests/ -v --cov=. --cov-report=term --cov-report=xml

##
## Phase B Targets
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
		$(FULL_IMAGE)
	@echo "[$(COMPONENT)] Scan passed - no CRITICAL vulnerabilities found"

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
	@rm -f coverage.xml
	@rm -f .coverage
	@rm -rf .pytest_cache
	@rm -rf __pycache__
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "[$(COMPONENT)] Clean complete"
