# K8s Cluster Product - Local Implementation (k3s)

Single-node k3s Kubernetes cluster deployed on Ubuntu VM using libvirt/KVM.

## Overview

This implementation provides a lightweight Kubernetes cluster suitable for:
- Local development and testing
- Private cloud deployments
- IDP product demonstrations
- CI/CD pipeline testing

## Architecture

- **Kubernetes Distribution**: k3s (lightweight, production-ready)
- **Node Configuration**: Single server node
- **Hypervisor**: libvirt/KVM
- **Operating System**: Ubuntu 22.04 LTS (Jammy)
- **Networking**: NAT mode (192.168.100.0/24)
- **Provisioning**: Cloud-init for automated setup
- **Infrastructure as Code**: Terraform

## Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04+ or compatible Linux distribution
- **CPU**: Virtualization support (Intel VT-x or AMD-V)
- **Memory**: Minimum 4GB RAM (2GB for VM, 2GB for host)
- **Disk**: Minimum 20GB free space
- **Network**: Internet connectivity for downloading images and k3s

### Software Requirements

1. **KVM/QEMU and libvirt**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

   # Enable and start libvirt
   sudo systemctl enable --now libvirtd

   # Add user to libvirt group
   sudo usermod -a -G libvirt $USER
   newgrp libvirt

   # Verify installation
   virsh list --all
   ```

2. **Terraform** (>= 1.5.0):
   ```bash
   wget -O- https://apt.releases.hashicorp.com/gpg | \
     sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
     https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
     sudo tee /etc/apt/sources.list.d/hashicorp.list

   sudo apt-get update && sudo apt-get install terraform

   # Verify installation
   terraform version
   ```

3. **kubectl**:
   ```bash
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

   # Verify installation
   kubectl version --client
   ```

4. **SSH Key Pair**:
   ```bash
   # Generate if not present
   [ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
   ```

## Quick Start

### Step 1: Navigate to Example Directory

```bash
cd products/k8s-cluster/local/example
```

### Step 2: Initialize Terraform

```bash
terraform init
```

This downloads the required providers (libvirt).

### Step 3: Review Configuration

```bash
# Copy example config (optional)
cp terraform.tfvars.example terraform.tfvars

# Edit if needed
vim terraform.tfvars

# Review the plan
terraform plan
```

### Step 4: Deploy Cluster

```bash
terraform apply
```

This process takes approximately 3-5 minutes:
1. Downloads Ubuntu cloud image (~700MB, first time only)
2. Creates VM with 2GB RAM, 2 vCPU
3. Provisions VM with cloud-init
4. Installs k3s server
5. Extracts kubeconfig
6. Creates namespace and service account

### Step 5: Access Cluster

```bash
# Admin access
export KUBECONFIG=demo-k3s-kubeconfig.yaml
kubectl get nodes
kubectl get pods -A

# Service account access
export KUBECONFIG=demo-k3s-sa-kubeconfig.yaml
kubectl get pods -n demo-app

# SSH to server
ssh ubuntu@<SERVER_IP>  # IP shown in terraform output
```

### Step 6: Cleanup

```bash
terraform destroy -auto-approve
```

## Module Inputs

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `cluster_name` | Name of the k3s cluster | string | `k3s-local` | no |
| `k3s_version` | K3s version to install | string | `v1.28.5+k3s1` | no |
| `ubuntu_image_url` | Ubuntu cloud image URL | string | Ubuntu 22.04 LTS | no |
| `storage_pool` | Libvirt storage pool name | string | `default` | no |
| `disk_size` | Disk size in bytes | number | `21474836480` (20GB) | no |
| `server_memory` | Server node memory in MB | number | `2048` | no |
| `server_vcpu` | Server node vCPU count | number | `2` | no |
| `ssh_public_key` | SSH public key for VM access | string | n/a | yes |
| `network_interface` | Network interface for k3s | string | `eth0` | no |
| `namespace` | K8s namespace for workloads | string | `default` | no |
| `service_account` | K8s service account name | string | `workload-sa` | no |

## Module Outputs

| Output | Description |
|--------|-------------|
| `server_ip` | IP address of k3s server node |
| `cluster_endpoint` | Kubernetes API endpoint URL |
| `kubeconfig_path` | Path to admin kubeconfig file |
| `namespace` | Created namespace name |
| `service_account` | Created service account name |
| `service_account_kubeconfig_path` | Path to SA kubeconfig file |
| `ssh_connection` | SSH connection command |
| `networking_details` | Network configuration details |

## How It Works

### 1. Cloud-Init Provisioning

The `cloud-init/server.yaml.tpl` template:
- Configures hostname and users
- Installs required packages
- Disables swap (required for Kubernetes)
- Creates k3s configuration file
- Installs k3s using official install script
- Waits for k3s to become ready
- Exports kubeconfig with external IP

### 2. VM Creation

Terraform creates:
- NAT network (192.168.100.0/24)
- Ubuntu base image volume
- Server-specific volume (copy-on-write from base)
- Cloud-init ISO with rendered template
- Libvirt domain (VM) with configured resources

### 3. Post-Deployment Automation

Scripts automatically:
- **extract-kubeconfig.sh**: Retrieves admin kubeconfig via SSH
- **create-namespace-sa.sh**: Creates namespace, service account, and scoped kubeconfig

## Networking

### NAT Mode (Default)

- **CIDR**: 192.168.100.0/24
- **DHCP**: Enabled (automatic IP assignment)
- **DNS**: Enabled
- **Internet**: Outbound connectivity via host NAT
- **Access**: From host to VM (direct), from external (port forwarding required)

### Accessing Services

```bash
# Option 1: kubectl port-forward
kubectl port-forward -n demo-app deployment/myapp 8080:8080

# Option 2: NodePort service (access via VM IP)
kubectl expose deployment myapp --type=NodePort --port=8080 -n demo-app
# Access at http://<SERVER_IP>:<NODE_PORT>

# Option 3: SSH tunnel
ssh -L 8080:localhost:8080 ubuntu@<SERVER_IP>
```

## Troubleshooting

### Issue: Libvirt permission denied

```bash
# Ensure user is in libvirt group
sudo usermod -a -G libvirt $USER
newgrp libvirt

# Check libvirt is running
sudo systemctl status libvirtd
```

### Issue: VM not getting IP address

```bash
# Check VM status
virsh list --all
virsh dominfo <cluster-name>-server

# Check network
virsh net-list --all
virsh net-info <cluster-name>-network

# Restart network
virsh net-destroy <cluster-name>-network
virsh net-start <cluster-name>-network
```

### Issue: k3s not starting

```bash
# SSH to VM
ssh ubuntu@<SERVER_IP>

# Check cloud-init status
sudo cloud-init status --wait
sudo cat /var/log/cloud-init-output.log

# Check k3s service
sudo systemctl status k3s
sudo journalctl -u k3s -n 50

# Manual k3s commands
sudo kubectl get nodes
```

### Issue: Cannot access cluster

```bash
# Verify kubeconfig exists
ls -la *kubeconfig.yaml

# Test connectivity
ping <SERVER_IP>

# Verify k3s API is listening
curl -k https://<SERVER_IP>:6443

# Re-extract kubeconfig
./scripts/extract-kubeconfig.sh <SERVER_IP> <cluster-name>
```

### Issue: Terraform apply hangs

```bash
# Check if scripts are executable
ls -la scripts/*.sh

# Make executable if needed
chmod +x scripts/*.sh

# Check script output
# Scripts may be waiting for k3s to become ready (max 5 minutes)
```

## Advanced Usage

### Custom k3s Configuration

Modify `cloud-init/server.yaml.tpl` to add k3s server flags:

```yaml
write_files:
  - path: /etc/rancher/k3s/config.yaml
    content: |
      write-kubeconfig-mode: "0644"
      disable:
        - traefik        # Disable built-in ingress
        - servicelb      # Disable built-in load balancer
      kube-apiserver-arg:
        - "enable-admission-plugins=PodSecurityPolicy"
```

### Resource Adjustment

```hcl
# In example/terraform.tfvars
server_memory = 4096  # Increase to 4GB RAM
server_vcpu   = 4     # Increase to 4 vCPU
```

### Multiple Clusters

```bash
# Deploy multiple clusters with different names
terraform apply -var="cluster_name=dev-cluster"
terraform apply -var="cluster_name=test-cluster"
```

### Integration with Other Products

This module outputs can be consumed by higher-level products:

```hcl
module "k8s_cluster" {
  source = "../products/k8s-cluster/local"
  # ... configuration
}

module "postgres" {
  source = "../products/postgresql/local"
  # ... configuration
}

module "three_tier_app" {
  source = "../products/three-tier-webapp"

  cluster_endpoint = module.k8s_cluster.cluster_endpoint
  cluster_kubeconfig = module.k8s_cluster.kubeconfig_path
  db_connection = module.postgres.connection_string
  # ... other configuration
}
```

## Files and Structure

```
local/
├── README.md                   # This file
├── main.tf                     # Main resources (VMs, network, cloud-init)
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
├── versions.tf                 # Provider requirements
├── cloud-init/
│   └── server.yaml.tpl        # Cloud-init template for server
├── scripts/
│   ├── extract-kubeconfig.sh  # Kubeconfig extraction automation
│   └── create-namespace-sa.sh # Namespace and SA creation
└── example/
    ├── main.tf                # Example usage
    ├── variables.tf           # Example variables
    ├── outputs.tf             # Example outputs
    └── terraform.tfvars.example
```

## Known Limitations

1. **Single Node**: Current implementation is single-node only (no HA)
2. **NAT Networking**: Services not directly accessible from external networks
3. **Resource Constraints**: Minimum 2GB RAM required for k3s server
4. **Linux Only**: Requires Linux host with KVM support
5. **Storage**: Uses local storage only (no persistent volume provisioner)

## Future Enhancements

- [ ] Multi-node support (1 server + N agents)
- [ ] Bridge networking option
- [ ] Helm provider integration
- [ ] Pre-installed addons (MetalLB, ingress-nginx)
- [ ] Automated backup/restore
- [ ] Monitoring stack (Prometheus, Grafana)

## Related Documentation

- [k3s Documentation](https://docs.k3s.io/)
- [Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
