# Scripts Directory

Helper scripts for setting up and testing the hello-world IDP products.

## Available Scripts

### 1. setup-k8s-local-dev.sh

Sets up the local development environment for testing the K8s Cluster Product.

**What it does:**
- Checks CPU virtualization support (Intel VT-x / AMD-V)
- Installs libvirt/KVM packages (including genisoimage for mkisofs)
- Configures and starts libvirtd service
- Creates/verifies default storage pool
- Adds user to libvirt group
- Verifies Terraform installation
- Installs kubectl
- Generates SSH key pair (if needed)
- Verifies libvirt connectivity

**Prerequisites:**
- Ubuntu 20.04+ or compatible Linux
- sudo privileges
- KVM-capable CPU

**Usage:**
```bash
chmod +x scripts/setup-k8s-local-dev.sh
./scripts/setup-k8s-local-dev.sh
```

**After running:**
If prompted, activate the libvirt group membership:
```bash
newgrp libvirt
```

### 2. test-k8s-cluster.sh

Deploys and tests the k3s cluster using the example configuration.

**What it does:**
- Verifies all prerequisites are installed
- Cleans up any existing deployments
- Runs `terraform init`
- Validates Terraform configuration
- Plans and applies the deployment
- Waits for cluster to be ready (3-5 minutes)
- Tests kubectl connectivity
- Checks node and pod status
- Deploys a test nginx pod
- Tests service account access
- Verifies SSH connectivity
- Displays cluster information
- Optionally destroys the cluster

**Prerequisites:**
- Run `setup-k8s-local-dev.sh` first
- Be in the libvirt group (`newgrp libvirt`)

**Usage:**
```bash
chmod +x scripts/test-k8s-cluster.sh
./scripts/test-k8s-cluster.sh
```

**What to expect:**
- Total time: 5-7 minutes
- Downloads Ubuntu cloud image (700MB, first time only)
- Creates VM with k3s
- Runs automated tests
- Prompts whether to keep or destroy cluster

## Quick Start

Complete setup and test in one go:

```bash
# 1. Run setup
./scripts/setup-k8s-local-dev.sh

# 2. Activate group (if needed)
newgrp libvirt

# 3. Run test
./scripts/test-k8s-cluster.sh
```

## Troubleshooting

### "Cannot connect to libvirt"
Run: `newgrp libvirt` or log out and back in.

### "virsh not found"
Run the setup script first: `./scripts/setup-k8s-local-dev.sh`

### "No CPU virtualization support"
Enable Intel VT-x or AMD-V in your BIOS/UEFI settings.

### "Permission denied" errors
Ensure scripts are executable: `chmod +x scripts/*.sh`

## Manual Testing

If you prefer manual testing instead of using the test script:

```bash
cd products/k8s-cluster/local/example
terraform init
terraform plan
terraform apply

# Use the cluster
export KUBECONFIG=demo-k3s-kubeconfig.yaml
kubectl get nodes
kubectl get pods -A

# Cleanup
terraform destroy
```

## Notes

- The test script creates a cluster named `demo-k3s` by default
- VMs are created in libvirt's default storage pool
- Network uses NAT mode (192.168.100.0/24)
- SSH keys are read from `~/.ssh/id_rsa.pub`
- All clusters can be listed with: `virsh list --all`
