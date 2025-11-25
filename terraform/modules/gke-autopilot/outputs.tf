output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_id" {
  description = "Cluster ID"
  value       = google_container_cluster.primary.id
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (base64 encoded)"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Cluster location (region)"
  value       = google_container_cluster.primary.location
}

output "workload_identity_pool" {
  description = "Workload Identity pool for the cluster"
  value       = "${var.project_id}.svc.id.goog"
}

output "cluster_ipv4_cidr" {
  description = "IPv4 CIDR block for pods"
  value       = google_container_cluster.primary.ip_allocation_policy[0].cluster_ipv4_cidr_block
}

output "services_ipv4_cidr" {
  description = "IPv4 CIDR block for services"
  value       = google_container_cluster.primary.ip_allocation_policy[0].services_ipv4_cidr_block
}

output "master_version" {
  description = "Kubernetes master version"
  value       = google_container_cluster.primary.master_version
}

output "network" {
  description = "Network name"
  value       = google_container_cluster.primary.network
}

output "subnetwork" {
  description = "Subnetwork name"
  value       = google_container_cluster.primary.subnetwork
}
