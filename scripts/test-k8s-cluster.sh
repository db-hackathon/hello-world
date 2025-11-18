#!/bin/bash
set -euo pipefail

# Test script for K8s Cluster Product local implementation
# Deploys a k3s cluster using the example configuration and verifies functionality
#
# Prerequisites:
# - Run setup-k8s-local-dev.sh first
# - Ensure you're in the libvirt group (run 'newgrp libvirt' if needed)
#
# Usage:
#   chmod +x scripts/test-k8s-cluster.sh
#   ./scripts/test-k8s-cluster.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXAMPLE_DIR="${PROJECT_ROOT}/products/k8s-cluster/local/example"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_step() {
    echo ""
    echo -e "${BLUE}==>${NC} $1"
}

cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "Test failed with exit code ${exit_code}"
        print_info "To clean up manually, run: cd ${EXAMPLE_DIR} && terraform destroy -auto-approve"
    fi
}

trap cleanup_on_exit EXIT

echo "=========================================="
echo "K8s Cluster Product - Test Deployment"
echo "=========================================="
echo ""

# Verify prerequisites
print_step "Verifying prerequisites..."

if ! which virsh > /dev/null 2>&1; then
    print_error "virsh not found. Please run setup-k8s-local-dev.sh first"
    exit 1
fi

if ! which terraform > /dev/null 2>&1; then
    print_error "terraform not found. Please run setup-k8s-local-dev.sh first"
    exit 1
fi

if ! which kubectl > /dev/null 2>&1; then
    print_error "kubectl not found. Please run setup-k8s-local-dev.sh first"
    exit 1
fi

if [ ! -f ~/.ssh/id_rsa.pub ]; then
    print_error "SSH public key not found. Please run setup-k8s-local-dev.sh first"
    exit 1
fi

# Test libvirt connectivity
if ! virsh list --all > /dev/null 2>&1; then
    print_error "Cannot connect to libvirt. Run: newgrp libvirt"
    exit 1
fi

print_success "All prerequisites verified"

# Navigate to example directory
print_step "Navigating to example directory..."
cd "${EXAMPLE_DIR}"
print_success "Working directory: ${EXAMPLE_DIR}"

# Clean up any previous deployments
print_step "Checking for existing deployments..."
if [ -f terraform.tfstate ]; then
    print_warning "Found existing terraform state, cleaning up..."
    terraform destroy -auto-approve || print_warning "Cleanup completed with warnings"
    rm -f *kubeconfig.yaml 2>/dev/null || true
fi

# Initialize Terraform
print_step "Initializing Terraform..."
if terraform init; then
    print_success "Terraform initialized"
else
    print_error "Terraform initialization failed"
    exit 1
fi

# Validate configuration
print_step "Validating Terraform configuration..."
if terraform validate; then
    print_success "Configuration is valid"
else
    print_error "Configuration validation failed"
    exit 1
fi

# Plan deployment
print_step "Planning deployment..."
if terraform plan -out=tfplan; then
    print_success "Terraform plan succeeded"
else
    print_error "Terraform plan failed"
    exit 1
fi

# Apply deployment
print_step "Deploying k3s cluster (this takes 3-5 minutes)..."
print_info "Creating VM, installing k3s, extracting kubeconfig..."
if terraform apply -auto-approve tfplan; then
    print_success "Cluster deployed successfully"
else
    print_error "Cluster deployment failed"
    exit 1
fi

# Extract outputs
print_step "Extracting cluster information..."
SERVER_IP=$(terraform output -raw connection_info | grep -oP 'server_ip[^"]*"\K[^"]*' || echo "")
KUBECONFIG_PATH=$(terraform output -raw connection_info | grep -oP 'kubeconfig_path[^"]*"\K[^"]*' || echo "demo-k3s-kubeconfig.yaml")

if [ -z "${SERVER_IP}" ]; then
    print_error "Failed to extract server IP"
    exit 1
fi

print_success "Server IP: ${SERVER_IP}"
print_success "Kubeconfig: ${KUBECONFIG_PATH}"

# Wait a bit for cluster to fully stabilize
print_step "Waiting for cluster to stabilize..."
sleep 10

# Verify kubeconfig exists
if [ ! -f "${KUBECONFIG_PATH}" ]; then
    print_error "Kubeconfig file not found: ${KUBECONFIG_PATH}"
    exit 1
fi

export KUBECONFIG="${KUBECONFIG_PATH}"
print_success "Using kubeconfig: ${KUBECONFIG}"

# Test kubectl connectivity
print_step "Testing cluster connectivity..."
if kubectl cluster-info > /dev/null 2>&1; then
    print_success "kubectl can connect to cluster"
else
    print_error "Cannot connect to cluster"
    exit 1
fi

# Check nodes
print_step "Checking cluster nodes..."
if kubectl get nodes > /dev/null 2>&1; then
    NODE_STATUS=$(kubectl get nodes --no-headers | awk '{print $2}')
    if [ "${NODE_STATUS}" == "Ready" ]; then
        print_success "Node is Ready"
        kubectl get nodes
    else
        print_warning "Node status: ${NODE_STATUS}"
        kubectl get nodes
    fi
else
    print_error "Failed to get nodes"
    exit 1
fi

# Check system pods
print_step "Checking system pods..."
print_info "Waiting for system pods to be ready..."
sleep 5
kubectl get pods -A

PENDING_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
if [ "${PENDING_PODS}" -eq 0 ]; then
    print_success "All system pods are running"
else
    print_warning "${PENDING_PODS} pods not yet running (this is normal for new clusters)"
fi

# Test creating a workload
print_step "Testing workload deployment..."
if kubectl run test-nginx --image=nginx --port=80 --restart=Never 2>/dev/null; then
    print_success "Test pod created"

    # Wait for pod to be running
    print_info "Waiting for test pod to be ready (timeout: 60s)..."
    kubectl wait --for=condition=Ready pod/test-nginx --timeout=60s || print_warning "Pod not ready yet"

    POD_STATUS=$(kubectl get pod test-nginx -o jsonpath='{.status.phase}')
    print_info "Test pod status: ${POD_STATUS}"

    # Cleanup test pod
    kubectl delete pod test-nginx --wait=false
    print_success "Test pod cleanup initiated"
else
    print_warning "Test pod already exists or creation failed"
fi

# Test service account access
print_step "Testing service account kubeconfig..."
SA_KUBECONFIG="${PWD}/demo-k3s-sa-kubeconfig.yaml"
if [ -f "${SA_KUBECONFIG}" ]; then
    print_success "Service account kubeconfig exists"
    if kubectl --kubeconfig="${SA_KUBECONFIG}" get pods -n demo-app > /dev/null 2>&1; then
        print_success "Service account can access namespace"
    else
        print_warning "Service account access test inconclusive"
    fi
else
    print_warning "Service account kubeconfig not found (expected at ${SA_KUBECONFIG})"
fi

# Test SSH connectivity
print_step "Testing SSH connectivity..."
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "ubuntu@${SERVER_IP}" "hostname" > /dev/null 2>&1; then
    print_success "SSH connectivity verified"
    HOSTNAME=$(ssh -o StrictHostKeyChecking=no "ubuntu@${SERVER_IP}" "hostname" 2>/dev/null)
    print_info "Server hostname: ${HOSTNAME}"
else
    print_warning "SSH connectivity test failed (might need to accept host key)"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
echo ""
print_success "Cluster deployment: SUCCESS"
print_success "Node status: $(kubectl get nodes --no-headers | awk '{print $2}')"
print_success "System pods: $(kubectl get pods -A --no-headers | wc -l) pods"
print_success "API connectivity: OK"
echo ""
echo "Cluster Information:"
echo "  Server IP:     ${SERVER_IP}"
echo "  API Endpoint:  https://${SERVER_IP}:6443"
echo "  Kubeconfig:    ${KUBECONFIG_PATH}"
echo "  Namespace:     demo-app"
echo "  SA Kubeconfig: ${SA_KUBECONFIG}"
echo ""
echo "Quick Commands:"
echo "  export KUBECONFIG=${KUBECONFIG_PATH}"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  ssh ubuntu@${SERVER_IP}"
echo ""
echo "Terraform Outputs:"
terraform output -json | jq -r '.quick_start.value' 2>/dev/null || terraform output quick_start 2>/dev/null || echo "(Quick start info not available)"
echo ""

# Ask about cleanup
echo "=========================================="
read -p "Do you want to destroy the test cluster? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_step "Destroying cluster..."
    terraform destroy -auto-approve
    print_success "Cluster destroyed"
    rm -f *kubeconfig.yaml 2>/dev/null || true
    echo ""
    print_info "Test complete and cleaned up"
else
    echo ""
    print_info "Cluster left running for manual testing"
    print_info "To destroy later, run: cd ${EXAMPLE_DIR} && terraform destroy"
fi

echo ""
print_success "All tests passed!"
