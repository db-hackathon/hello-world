output "nat_router_name" {
  description = "Name of the Cloud Router"
  value       = var.create_nat ? google_compute_router.nat_router[0].name : var.nat_router_name
}

output "nat_config_name" {
  description = "Name of the Cloud NAT configuration"
  value       = var.create_nat ? google_compute_router_nat.nat_config[0].name : var.nat_config_name
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "network_name" {
  description = "VPC network name"
  value       = var.network_name
}

output "enabled_apis" {
  description = "List of enabled GCP APIs"
  value = [
    google_project_service.sqladmin.service,
    google_project_service.container.service,
    google_project_service.compute.service,
  ]
}
