# K8s Cluster Product

Creates a Kubernetes cluster in your chosen hosting venue with full networking and access management configured automatically.

## Overview

This product provides a standardized Kubernetes cluster deployment that abstracts away venue-specific details. Whether you're deploying to public cloud (GKE) or private cloud (k3s on VM), the product provides consistent outputs including cluster credentials, namespace, service account, and networking details.

## Purpose

This product is designed for Internal Developer Platform (IDP) integration, allowing platform engineers to offer Kubernetes clusters as a self-service product. It serves as a building block for higher-level products like the Three Tier Web App.

## Implementations

### Private Cloud (default)
- **Technology**: k3s on Ubuntu VM
- **Hypervisor**: libvirt/KVM
- **Networking**: NAT mode (192.168.100.0/24)
- **Use Case**: Local development, private cloud deployments
- **Location**: `./local/`

### Public Cloud (future)
- **Technology**: Google Kubernetes Engine (GKE)
- **Cloud Provider**: Google Cloud Platform
- **Use Case**: Production workloads, cloud-native applications
- **Location**: `./gke/` (to be implemented)

## Inputs

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `venue` | Deployment venue: `public-cloud` or `private-cloud` | string | `private-cloud` | no |
| `cluster_name` | Name of the Kubernetes cluster | string | n/a | yes |
| `ssh_public_key` | SSH public key for VM access (private-cloud only) | string | n/a | yes |
| `namespace` | Kubernetes namespace to create for workloads | string | `default` | no |
| `service_account` | Kubernetes service account name for workload identity | string | `workload-sa` | no |
| `k3s_version` | K3s version to install (private-cloud only) | string | `v1.28.5+k3s1` | no |
| `server_memory` | Server node memory in MB (private-cloud only) | number | `2048` | no |
| `server_vcpu` | Server node vCPU count (private-cloud only) | number | `2` | no |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_credentials` | Path to kubeconfig file for cluster access |
| `namespace` | Kubernetes namespace created for workloads |
| `service_account` | Kubernetes service account name for workload identity |
| `service_account_credentials` | Path to service account kubeconfig file |
| `cluster_endpoint` | Kubernetes API server endpoint URL |
| `networking_details` | Networking information (IPs, CIDR, mode) |
| `ssh_connection` | SSH connection string (private-cloud only) |
| `server_ip` | IP address of server node (private-cloud only) |

## Usage Example

### Private Cloud Deployment

```hcl
module "k8s_cluster" {
  source = "./products/k8s-cluster"

  venue           = "private-cloud"
  cluster_name    = "my-k3s-cluster"
  ssh_public_key  = file("~/.ssh/id_rsa.pub")

  namespace       = "my-app"
  service_account = "my-app-sa"

  k3s_version   = "v1.28.5+k3s1"
  server_memory = 2048
  server_vcpu   = 2
}

output "cluster_info" {
  value = {
    endpoint         = module.k8s_cluster.cluster_endpoint
    kubeconfig       = module.k8s_cluster.cluster_credentials
    namespace        = module.k8s_cluster.namespace
    service_account  = module.k8s_cluster.service_account
  }
}
```

### Public Cloud Deployment (future)

```hcl
module "k8s_cluster" {
  source = "./products/k8s-cluster"

  venue           = "public-cloud"
  cluster_name    = "my-gke-cluster"

  namespace       = "my-app"
  service_account = "my-app-sa"

  # GKE-specific variables (to be defined)
  # gke_region = "us-central1"
  # node_count = 3
}
```

## What This Product Provides

1. **Kubernetes Cluster**: Fully functional single-node cluster (k3s) or multi-node cluster (GKE)
2. **Cluster Credentials**: Admin kubeconfig file for cluster management
3. **Workload Namespace**: Dedicated namespace for application deployment
4. **Service Account**: Kubernetes service account with cluster-admin privileges
5. **Service Account Credentials**: Scoped kubeconfig for workload deployment
6. **Networking**: Configured networking with accessible cluster endpoint
7. **SSH Access**: Direct SSH access to cluster nodes (private-cloud only)

## IDP Integration

This product is designed to be advertised in IDP catalogs with the following metadata:

- **Product Type**: Infrastructure
- **Category**: Compute / Orchestration
- **Dependencies**: None (foundational product)
- **Consumers**: Three Tier Web App Product, custom applications
- **Lifecycle**: Managed by Terraform
- **Cost**: Variable by venue and resource allocation

## Prerequisites

### For Private Cloud Deployment

1. **Libvirt/KVM**: Install virtualization packages
   ```bash
   sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients
   sudo systemctl enable --now libvirtd
   sudo usermod -a -G libvirt $USER
   newgrp libvirt
   ```

2. **Terraform**: Version >= 1.5.0
   ```bash
   # Install via official HashiCorp repository
   ```

3. **SSH Key Pair**: Generate if not present
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   ```

4. **kubectl**: For cluster interaction
   ```bash
   # Install via package manager or download binary
   ```

### For Public Cloud Deployment (future)

- GCP account with appropriate permissions
- `gcloud` CLI configured
- GKE API enabled
- Terraform with Google provider

## Quick Start

See the example in `./local/example/` for a complete working implementation:

```bash
cd products/k8s-cluster/local/example
terraform init
terraform plan
terraform apply

# Use the cluster
export KUBECONFIG=demo-k3s-kubeconfig.yaml
kubectl get nodes
```

## Documentation

- **Local Implementation**: See [./local/README.md](./local/README.md)
- **GKE Implementation**: See [./gke/README.md](./gke/README.md) (future)

## Support

For issues, questions, or contributions related to this product, please refer to the main repository documentation.
