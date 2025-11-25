# GKE Autopilot Cluster Module
# Creates a regional GKE Autopilot cluster with private nodes and Workload Identity

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Autopilot mode - fully managed node pools
  enable_autopilot = true

  # Network configuration
  network    = var.network_name
  subnetwork = var.subnetwork_name

  # IP allocation for pods and services
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.cluster_ipv4_cidr_block
    services_ipv4_cidr_block = var.services_ipv4_cidr_block
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep public endpoint for Terraform access
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Master authorized networks (optional - for additional security)
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Workload Identity configuration
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel for automatic updates
  release_channel {
    channel = var.release_channel
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }

  # Network policy (Autopilot enables Dataplane V2 by default)
  # This ensures network policies are supported
  datapath_provider = "ADVANCED_DATAPATH"

  # Cluster autoscaling (Autopilot manages this automatically)
  # Note: In Autopilot mode, autoscaling is always enabled
  # We can only set the autoscaling profile
  cluster_autoscaling {
    autoscaling_profile = var.autoscaling_profile
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Labels for resource management
  resource_labels = var.labels

  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false # Set to true in production
  }
}
