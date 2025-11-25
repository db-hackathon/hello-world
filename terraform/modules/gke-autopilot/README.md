# GKE Autopilot Cluster Module

This module creates a regional GKE Autopilot cluster with private nodes and Workload Identity enabled.

## Features

- **Autopilot Mode**: Fully managed node pools with automatic scaling and optimization
- **Private Cluster**: Nodes without external IPs (requires Cloud NAT for egress)
- **Workload Identity**: Enables Kubernetes pods to authenticate as GCP service accounts
- **Regional Deployment**: High availability across multiple zones
- **Advanced Datapath**: GKE Dataplane V2 with eBPF-based networking
- **Automatic Updates**: Release channel for automatic Kubernetes version updates

## Resources Created

- `google_container_cluster.primary` - GKE Autopilot cluster

## Usage

```hcl
module "gke_autopilot" {
  source = "../../modules/gke-autopilot"

  project_id   = "extended-ascent-477308-m8"
  cluster_name = "hellow-world-manual"
  region       = "europe-west1"

  network_name    = "default"
  subnetwork_name = "default"

  # Private cluster configuration
  master_ipv4_cidr_block = "172.16.0.0/28"

  # Optional: Restrict access to Kubernetes API
  master_authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks"
    }
  ]

  labels = {
    environment = "staging"
    app         = "baby-names"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | n/a | yes |
| cluster_name | Name of the GKE cluster | string | n/a | yes |
| region | GCP region for the cluster | string | "europe-west1" | no |
| network_name | Name of the VPC network | string | "default" | no |
| subnetwork_name | Name of the subnetwork | string | "default" | no |
| cluster_ipv4_cidr_block | IP CIDR block for pods | string | "" (auto) | no |
| services_ipv4_cidr_block | IP CIDR block for services | string | "" (auto) | no |
| master_ipv4_cidr_block | IP CIDR block for Kubernetes master (must be /28) | string | "172.16.0.0/28" | no |
| master_authorized_networks | List of CIDR blocks allowed to access Kubernetes master | list(object) | [] | no |
| release_channel | Release channel (RAPID, REGULAR, STABLE) | string | "REGULAR" | no |
| maintenance_start_time | Daily maintenance window start time (HH:MM) | string | "03:00" | no |
| autoscaling_profile | Autoscaling profile (BALANCED, OPTIMIZE_UTILIZATION) | string | "BALANCED" | no |
| enable_managed_prometheus | Enable Google Cloud Managed Service for Prometheus | bool | false | no |
| deletion_protection | Enable deletion protection | bool | true | no |
| labels | Labels to apply to the cluster | map(string) | {} | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| cluster_name | Name of the GKE cluster | No |
| cluster_id | Cluster ID | No |
| cluster_endpoint | Kubernetes API endpoint | Yes |
| cluster_ca_certificate | Cluster CA certificate (base64 encoded) | Yes |
| cluster_location | Cluster location (region) | No |
| workload_identity_pool | Workload Identity pool | No |
| cluster_ipv4_cidr | IPv4 CIDR block for pods | No |
| services_ipv4_cidr | IPv4 CIDR block for services | No |
| master_version | Kubernetes master version | No |
| network | Network name | No |
| subnetwork | Subnetwork name | No |

## Dependencies

- **Cloud NAT**: Required for private cluster nodes to pull container images
- **Compute Engine API**: Must be enabled
- **Kubernetes Engine API**: Must be enabled

## Permissions Required

The Terraform execution service account needs:
- `roles/container.admin` - To create and manage GKE clusters

## Provisioning Time

- Initial cluster creation: **10-15 minutes**
- Updates may take several minutes depending on the change

## Important Notes

1. **Private Cluster Egress**: Private nodes require Cloud NAT to reach external registries (ghcr.io)
2. **Workload Identity**: Pods must use Kubernetes ServiceAccounts annotated with `iam.gke.io/gcp-service-account`
3. **Autopilot Limitations**: Some Kubernetes features are restricted in Autopilot mode
4. **Deletion Protection**: Set to `true` by default - update to `false` before destroying
5. **Master Authorized Networks**: If empty, defaults to allowing all IPs (0.0.0.0/0)
