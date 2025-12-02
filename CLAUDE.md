# CLAUDE.md

Guidance for Claude Code when working with this repository.

## Project Overview

Three-tier web application demonstrating Infrastructure Deployment Platform (IDP) capabilities through composable products and reference applications.

## Repository Structure

```
hello-world/
├── products/                    # IDP Products (composable infrastructure)
│   └── k8s-cluster/local/      # Local Kubernetes using kind
├── examples/
│   └── baby-names/             # Three-tier web app (Flask + PostgreSQL)
├── terraform/                  # GCP infrastructure modules
└── docs/agent/                 # Detailed reference docs (see below)
```

## Quick Reference

### Local Development

```bash
cd examples/baby-names
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock  # WSL2 only
docker-compose up -d
curl http://localhost:8080/?name=Noah
```

### Run CI Locally

```bash
cd examples/baby-names
make ci-local  # Format, lint, security, tests, build, scan
```

### Run Tests

```bash
cd examples/baby-names/backend && pytest tests/ -v --cov=.
cd examples/baby-names/frontend && pytest tests/ -v --cov=.
```

## Key Patterns

- **Containers**: Alpine Linux base, zero CRITICAL CVEs
- **Auth**: IAM database authentication, Workload Identity
- **Infra**: Terraform creates namespace/SA/RBAC; Helm creates workloads only
- **CI/CD**: Three-phase pipeline with supply chain attestations

## Contributing

**Every commit MUST include CHANGELOG updates** in `examples/baby-names/CHANGELOG.md` following [Keep a Changelog v1.1.0](https://keepachangelog.com/en/1.1.0/).

Categories: Added, Changed, Deprecated, Removed, Fixed, Security

## Detailed Documentation

For comprehensive reference information, consult these docs:

| Topic | Document |
|-------|----------|
| Architecture & patterns | [docs/agent/architecture.md](docs/agent/architecture.md) |
| Local development setup | [docs/agent/local-development.md](docs/agent/local-development.md) |
| CI/CD pipeline details | [docs/agent/ci-cd-pipeline.md](docs/agent/ci-cd-pipeline.md) |
| GKE deployment | [docs/agent/gke-deployment.md](docs/agent/gke-deployment.md) |
| Terraform infrastructure | [docs/agent/terraform-infrastructure.md](docs/agent/terraform-infrastructure.md) |
| Troubleshooting | [docs/agent/troubleshooting.md](docs/agent/troubleshooting.md) |

Also see:
- [Terraform Modules](terraform/README.md)
- [Terraform Executor Setup](terraform/docs/TERRAFORM_EXECUTOR_SETUP.md)
- [Baby Names README](examples/baby-names/README.md)
