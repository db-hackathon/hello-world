# K8s Cluster Product - Wrapper Module
# Delegates to venue-specific implementation

module "k8s_cluster" {
  source = var.venue == "public-cloud" ? "./gke" : "./local"

  cluster_name    = var.cluster_name
  ssh_public_key  = var.ssh_public_key
  namespace       = var.namespace
  service_account = var.service_account

  # Pass through venue-specific variables
  # For local (k3s) implementation
  k3s_version   = var.k3s_version
  server_memory = var.server_memory
  server_vcpu   = var.server_vcpu

  # For GKE implementation (future)
  # gke_region = var.gke_region
  # node_count = var.node_count
}
