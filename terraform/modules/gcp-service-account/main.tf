# GCP Service Account Module
# Creates application workload service account and IAM bindings

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Create GCP service account for application workload
resource "google_service_account" "app" {
  account_id   = var.service_account_id
  display_name = var.display_name
  description  = var.description
  project      = var.project_id
}

# Project-level IAM binding: Cloud SQL Client
# Allows establishing connections to Cloud SQL instances
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Project-level IAM binding: Cloud SQL Instance User (conditional)
# Allows IAM-based login to specific CloudSQL instances
resource "google_project_iam_member" "cloudsql_instance_user" {
  count   = var.enable_cloudsql_instance_user_role ? 1 : 0
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.app.email}"

  # Optional: Add condition for specific instances
  # condition {
  #   title       = "CloudSQL instance access"
  #   description = "Restrict to specific CloudSQL instance"
  #   expression  = "resource.matchTagId('tagKeys/XXXX', 'tagValues/YYYY')"
  # }
}

# Service Account-level IAM binding: Workload Identity User
# Allows Kubernetes ServiceAccount to impersonate this GCP ServiceAccount
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account_name}]"
}
