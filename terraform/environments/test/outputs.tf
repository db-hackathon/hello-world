# Outputs for Staging Environment

# GCP Project
output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

# Network
output "nat_router_name" {
  description = "Cloud Router name"
  value       = module.gcp_project_setup.nat_router_name
}

output "enabled_apis" {
  description = "Enabled GCP APIs"
  value       = module.gcp_project_setup.enabled_apis
}

# GKE Cluster
output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke_autopilot.cluster_name
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = module.gke_autopilot.cluster_location
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke_autopilot.cluster_endpoint
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload Identity pool"
  value       = module.gke_autopilot.workload_identity_pool
}

output "get_credentials_command" {
  description = "Command to get GKE cluster credentials"
  value       = "gcloud container clusters get-credentials ${module.gke_autopilot.cluster_name} --region=${var.region} --project=${var.project_id}"
}

# GCP Service Account
output "gcp_service_account_email" {
  description = "GCP service account email"
  value       = module.gcp_service_account.service_account_email
}

output "cloudsql_iam_user" {
  description = "CloudSQL IAM database user name"
  value       = module.gcp_service_account.cloudsql_iam_user
}

# CloudSQL
output "cloudsql_instance_name" {
  description = "CloudSQL instance name"
  value       = module.cloudsql.instance_name
}

output "cloudsql_instance_connection_name" {
  description = "CloudSQL instance connection name (for Cloud SQL Proxy)"
  value       = module.cloudsql.instance_connection_name
}

output "cloudsql_public_ip" {
  description = "CloudSQL public IP address"
  value       = module.cloudsql.public_ip_address
}

output "database_name" {
  description = "Database name"
  value       = module.cloudsql.database_name
}

# Kubernetes Resources
output "namespace" {
  description = "Kubernetes namespace"
  value       = module.k8s_namespace.namespace_name
}

output "k8s_service_account_name" {
  description = "Kubernetes ServiceAccount name"
  value       = module.k8s_namespace.service_account_name
}

output "image_pull_secret_name" {
  description = "Image pull secret name"
  value       = module.k8s_namespace.image_pull_secret_name
}

output "workload_identity_annotation" {
  description = "Workload Identity annotation on Kubernetes ServiceAccount"
  value       = module.k8s_namespace.workload_identity_annotation
}

# Database Bootstrap
output "database_bootstrap_completed" {
  description = "Database permissions bootstrap completed"
  value       = module.database_bootstrap.bootstrap_completed
}

# Helm Deployment Variables
output "helm_values" {
  description = "Values to use in Helm deployment"
  value = {
    namespace     = module.k8s_namespace.namespace_name
    database_host = "localhost" # via Cloud SQL Proxy
    database_port = "5432"
    database_name = module.cloudsql.database_name
    database_user = module.database_bootstrap.iam_database_user
    database_iam_auth = "true"
    instance_connection_name = module.cloudsql.instance_connection_name
  }
}

# Next Steps
output "next_steps" {
  description = "Next steps after Terraform apply"
  value = <<-EOT

  ✓ Infrastructure provisioning complete!

  Next steps:

  1. Get GKE credentials:
     gcloud container clusters get-credentials ${module.gke_autopilot.cluster_name} --region=${var.region} --project=${var.project_id}

  2. Verify Kubernetes resources:
     kubectl get namespace ${module.k8s_namespace.namespace_name}
     kubectl get sa ${module.k8s_namespace.service_account_name} -n ${module.k8s_namespace.namespace_name}
     kubectl get secret ${module.k8s_namespace.image_pull_secret_name} -n ${module.k8s_namespace.namespace_name}

  3. Deploy application via Helm:
     cd examples/baby-names/helm/baby-names
     helm upgrade --install baby-names . \
       --namespace ${module.k8s_namespace.namespace_name} \
       --values values-staging.yaml \
       --set backend.image.tag=main \
       --set frontend.image.tag=main \
       --set migration.image.tag=main \
       --wait --timeout 10m

  4. Verify deployment:
     kubectl get pods -n ${module.k8s_namespace.namespace_name}
     kubectl get svc -n ${module.k8s_namespace.namespace_name}
     kubectl get ingress -n ${module.k8s_namespace.namespace_name}

  Database connection details:
  - Host: localhost (via Cloud SQL Proxy)
  - Port: 5432
  - Database: ${module.cloudsql.database_name}
  - User: ${module.database_bootstrap.iam_database_user}
  - Auth: IAM (passwordless)

  EOT
}
