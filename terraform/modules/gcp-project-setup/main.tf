# GCP Project Setup Module
# Enables required APIs and configures Cloud NAT for private GKE cluster egress

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Enable required GCP APIs
resource "google_project_service" "sqladmin" {
  project = var.project_id
  service = "sqladmin.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# Cloud Router for Cloud NAT
resource "google_compute_router" "nat_router" {
  count = var.create_nat ? 1 : 0

  name    = var.nat_router_name
  network = var.network_name
  region  = var.region
  project = var.project_id

  depends_on = [google_project_service.compute]
}

# Cloud NAT configuration
# Purpose: Enable private GKE cluster nodes to reach external container registries (ghcr.io)
resource "google_compute_router_nat" "nat_config" {
  count = var.create_nat ? 1 : 0

  name    = var.nat_config_name
  router  = google_compute_router.nat_router[0].name
  region  = var.region
  project = var.project_id

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = var.nat_source_subnetwork_ip_ranges

  # Only used when source_subnetwork_ip_ranges_to_nat is LIST_OF_SUBNETWORKS
  dynamic "subnetwork" {
    for_each = var.nat_subnetworks
    content {
      name                     = subnetwork.value.name
      source_ip_ranges_to_nat  = subnetwork.value.source_ip_ranges_to_nat
      secondary_ip_range_names = subnetwork.value.secondary_ip_range_names
    }
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
