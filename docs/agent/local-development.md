# Local Development Reference

This document provides local development setup and workflow information for Claude Code.

## Prerequisites

- Docker/Podman
- Python 3.11+
- Terraform 1.5+ (for k8s-cluster product)
- kubectl (for k8s-cluster product)

## Quick Start (Baby Names)

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

## Testing

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

## Local CI Tools

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

## Podman Configuration (WSL2)

### Configure Registry Search

```bash
sudo tee /etc/containers/registries.conf.d/00-unqualified-search-registries.conf > /dev/null <<EOF
unqualified-search-registries = ["docker.io"]
EOF
```

### Set Docker Socket

```bash
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
# Add to ~/.bashrc for persistence
```

### Verify Setup

```bash
docker --version  # Should show: podman version X.X.X
docker ps
```

## Local K8s Cluster (kind)

```bash
cd products/k8s-cluster/local
terraform init
terraform apply
export KUBECONFIG=./kubeconfig
kubectl get nodes
```
