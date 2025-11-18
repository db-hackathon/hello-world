#!/bin/bash
set -euo pipefail

# Fix script for common libvirt setup issues
# Fixes:
# 1. Missing 'default' storage pool
# 2. Missing mkisofs executable

echo "=========================================="
echo "Fixing libvirt setup issues"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "ℹ $1"
}

# Fix 1: Create default storage pool
echo "Step 1: Checking libvirt storage pool..."
if sudo virsh pool-list --all | grep -q "default"; then
    print_success "Default storage pool exists"

    # Make sure it's started
    if ! sudo virsh pool-list | grep -q "default.*active"; then
        print_info "Starting default storage pool..."
        sudo virsh pool-start default
        print_success "Storage pool started"
    fi

    # Make sure it's set to autostart
    if ! sudo virsh pool-list --all | grep -q "default.*yes"; then
        print_info "Setting storage pool to autostart..."
        sudo virsh pool-autostart default
        print_success "Storage pool set to autostart"
    fi
else
    print_info "Creating default storage pool..."
    sudo mkdir -p /var/lib/libvirt/images
    sudo virsh pool-define-as default dir --target /var/lib/libvirt/images
    sudo virsh pool-build default
    sudo virsh pool-start default
    sudo virsh pool-autostart default
    print_success "Default storage pool created and started"
fi

echo ""
echo "Storage pool status:"
sudo virsh pool-list --all

# Fix 2: Install mkisofs
echo ""
echo "Step 2: Checking mkisofs..."
if which mkisofs > /dev/null 2>&1; then
    print_success "mkisofs already installed"
else
    print_info "Installing genisoimage (provides mkisofs)..."
    sudo apt-get update
    sudo apt-get install -y genisoimage
    print_success "genisoimage installed"
fi

echo ""
echo "=========================================="
echo "Fixes applied successfully!"
echo "=========================================="
echo ""
echo "You can now run: ./scripts/test-k8s-cluster.sh"
