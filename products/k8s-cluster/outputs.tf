# Standardized outputs for K8s Cluster Product
# Works regardless of venue (public-cloud or private-cloud)

output "cluster_credentials" {
  description = "Path to kubeconfig file for cluster access"
  value       = module.k8s_cluster.kubeconfig_path
  sensitive   = false
}

output "namespace" {
  description = "Kubernetes namespace created for workloads"
  value       = module.k8s_cluster.namespace
}

output "service_account" {
  description = "Kubernetes service account name for workload identity"
  value       = module.k8s_cluster.service_account
}

output "service_account_credentials" {
  description = "Path to service account kubeconfig file"
  value       = module.k8s_cluster.service_account_kubeconfig_path
  sensitive   = false
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = module.k8s_cluster.cluster_endpoint
}

output "networking_details" {
  description = "Networking information for the cluster"
  value       = module.k8s_cluster.networking_details
}

# Venue-specific outputs (only populated for private-cloud)
output "ssh_connection" {
  description = "SSH connection string (private-cloud only)"
  value       = var.venue == "private-cloud" ? module.k8s_cluster.ssh_connection : null
}

output "server_ip" {
  description = "IP address of server node (private-cloud only)"
  value       = var.venue == "private-cloud" ? module.k8s_cluster.server_ip : null
}
