#!/bin/bash
set -euo pipefail

# Setup script for K8s Cluster Product local development environment
# This script installs and configures prerequisites for testing k3s-on-VM deployment
#
# Requirements:
# - Ubuntu 20.04+ or compatible Linux distribution
# - sudo privileges
# - KVM virtualization support (Intel VT-x or AMD-V)
#
# Usage:
#   chmod +x scripts/setup-k8s-local-dev.sh
#   ./scripts/setup-k8s-local-dev.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "K8s Cluster Local Development Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "ℹ $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root (don't use sudo)"
    print_info "The script will prompt for sudo password when needed"
    exit 1
fi

# Check virtualization support
echo "Step 1: Checking virtualization support..."
if grep -E 'vmx|svm' /proc/cpuinfo > /dev/null 2>&1; then
    print_success "CPU virtualization support detected"
else
    print_error "No CPU virtualization support detected"
    print_info "Please enable Intel VT-x or AMD-V in BIOS"
    exit 1
fi

if lsmod | grep kvm > /dev/null 2>&1; then
    print_success "KVM kernel modules loaded"
else
    print_warning "KVM modules not loaded, will be loaded after package installation"
fi

# Check if libvirt is already installed
echo ""
echo "Step 2: Installing libvirt/KVM packages..."
if which virsh > /dev/null 2>&1; then
    print_success "libvirt already installed (version: $(virsh --version))"
else
    print_info "Installing libvirt-daemon-system, libvirt-clients, qemu-kvm, bridge-utils, genisoimage..."
    sudo apt-get update
    sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils genisoimage
    print_success "libvirt packages installed"
fi

# Check for mkisofs (required for cloud-init ISOs)
if ! which mkisofs > /dev/null 2>&1; then
    print_info "Installing genisoimage (provides mkisofs for cloud-init)..."
    sudo apt-get install -y genisoimage
fi
print_success "mkisofs available (from genisoimage package)"

# Enable and start libvirtd service
echo ""
echo "Step 3: Configuring libvirt service..."
if sudo systemctl is-active --quiet libvirtd; then
    print_success "libvirtd service is running"
else
    print_info "Starting libvirtd service..."
    sudo systemctl enable --now libvirtd
    sleep 2
    if sudo systemctl is-active --quiet libvirtd; then
        print_success "libvirtd service started and enabled"
    else
        print_error "Failed to start libvirtd service"
        exit 1
    fi
fi

# Create/verify default storage pool
echo ""
echo "Step 4: Configuring libvirt storage pool..."
if sudo virsh pool-list --all 2>/dev/null | grep -q "default"; then
    print_success "Default storage pool exists"

    # Ensure it's started
    if ! sudo virsh pool-list 2>/dev/null | grep -q "default.*active"; then
        print_info "Starting default storage pool..."
        sudo virsh pool-start default
    fi

    # Ensure it's set to autostart
    if ! sudo virsh pool-list --all 2>/dev/null | grep -q "default.*yes"; then
        print_info "Setting storage pool to autostart..."
        sudo virsh pool-autostart default
    fi
    print_success "Storage pool is active and set to autostart"
else
    print_info "Creating default storage pool..."
    sudo mkdir -p /var/lib/libvirt/images
    sudo virsh pool-define-as default dir --target /var/lib/libvirt/images
    sudo virsh pool-build default
    sudo virsh pool-start default
    sudo virsh pool-autostart default
    print_success "Default storage pool created and configured"
fi

# Add user to libvirt group
echo ""
echo "Step 5: Configuring user permissions..."
if groups | grep -q libvirt; then
    print_success "User already in libvirt group"
else
    print_info "Adding user ${USER} to libvirt group..."
    sudo usermod -a -G libvirt "${USER}"
    print_success "User added to libvirt group"
    print_warning "You'll need to log out and back in (or run 'newgrp libvirt') for group changes to take effect"
fi

# Check Terraform
echo ""
echo "Step 6: Checking Terraform..."
if which terraform > /dev/null 2>&1; then
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1 | awk '{print $2}')
    print_success "Terraform installed: ${TERRAFORM_VERSION}"
else
    print_error "Terraform not found"
    print_info "Install Terraform from: https://developer.hashicorp.com/terraform/install"
    exit 1
fi

# Install kubectl
echo ""
echo "Step 7: Installing kubectl..."
if which kubectl > /dev/null 2>&1; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | awk '{print $3}' || kubectl version --client | grep "Client Version" | awk '{print $3}')
    print_success "kubectl already installed: ${KUBECTL_VERSION}"
else
    print_info "Downloading and installing kubectl..."
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    print_success "kubectl installed: ${KUBECTL_VERSION}"
fi

# Generate SSH key
echo ""
echo "Step 8: Checking SSH keys..."
if [ -f ~/.ssh/id_rsa ]; then
    print_success "SSH key pair already exists (~/.ssh/id_rsa)"
else
    print_info "Generating SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "${USER}@$(hostname)"
    print_success "SSH key pair generated"
fi

if [ -f ~/.ssh/id_rsa.pub ]; then
    print_success "SSH public key exists (~/.ssh/id_rsa.pub)"
else
    print_error "SSH public key not found"
    exit 1
fi

# Verify libvirt connectivity
echo ""
echo "Step 9: Verifying libvirt connectivity..."
if virsh list --all > /dev/null 2>&1; then
    print_success "libvirt connectivity verified"
elif sg libvirt -c "virsh list --all" > /dev/null 2>&1; then
    print_success "libvirt connectivity verified (via libvirt group)"
    print_warning "Run 'newgrp libvirt' or log out/in to activate group membership"
else
    print_error "Cannot connect to libvirt"
    print_info "Try running: newgrp libvirt"
    exit 1
fi

# Summary
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
print_success "All prerequisites installed successfully"
echo ""
echo "Installed/Verified:"
echo "  ✓ libvirt/KVM:     $(virsh --version)"
echo "  ✓ Storage pool:    default ($(sudo virsh pool-list | grep default | awk '{print $2}'))"
echo "  ✓ mkisofs:         $(which mkisofs)"
echo "  ✓ Terraform:       ${TERRAFORM_VERSION}"
echo "  ✓ kubectl:         ${KUBECTL_VERSION:-$(kubectl version --client --short 2>/dev/null | awk '{print $3}')}"
echo "  ✓ SSH keys:        ~/.ssh/id_rsa{,.pub}"
echo ""
echo "Next steps:"
echo "  1. If prompted, run: newgrp libvirt"
echo "  2. Navigate to example: cd products/k8s-cluster/local/example"
echo "  3. Initialize Terraform: terraform init"
echo "  4. Deploy cluster: terraform apply"
echo ""
echo "Test deployment script available at:"
echo "  ${PROJECT_ROOT}/scripts/test-k8s-cluster.sh"
echo ""
