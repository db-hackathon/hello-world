# GCP Project Setup Module

This module sets up foundational GCP infrastructure required for the baby-names application:

- Enables required GCP APIs
- Creates Cloud NAT for private GKE cluster egress

## Purpose

Private GKE clusters have nodes without external IP addresses. Cloud NAT is required for these nodes to:
- Pull container images from external registries (ghcr.io)
- Access external APIs during application runtime

## Resources Created

- `google_project_service.sqladmin` - Cloud SQL Admin API
- `google_project_service.container` - Kubernetes Engine API
- `google_project_service.compute` - Compute Engine API
- `google_compute_router.nat_router` - Cloud Router for NAT
- `google_compute_router_nat.nat_config` - Cloud NAT configuration

## Usage

```hcl
module "gcp_project_setup" {
  source = "../../modules/gcp-project-setup"

  project_id       = "extended-ascent-477308-m8"
  region           = "europe-west1"
  network_name     = "default"
  nat_router_name  = "nat-router"
  nat_config_name  = "nat-config"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | n/a | yes |
| region | GCP region for regional resources | string | "europe-west1" | no |
| network_name | Name of the VPC network | string | "default" | no |
| nat_router_name | Name of the Cloud Router for NAT | string | "nat-router" | no |
| nat_config_name | Name of the Cloud NAT configuration | string | "nat-config" | no |

## Outputs

| Name | Description |
|------|-------------|
| nat_router_name | Name of the Cloud Router |
| nat_config_name | Name of the Cloud NAT configuration |
| region | GCP region |
| network_name | VPC network name |
| enabled_apis | List of enabled GCP APIs |

## Dependencies

None - this is typically the first module to run.

## Permissions Required

The Terraform execution service account needs:
- `roles/serviceusage.serviceUsageAdmin` - To enable APIs
- `roles/compute.networkAdmin` - To create Cloud Router and NAT
