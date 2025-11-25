output "namespace_name" {
  description = "Name of the Kubernetes namespace"
  value       = local.namespace
}

output "service_account_name" {
  description = "Name of the Kubernetes ServiceAccount"
  value       = kubernetes_service_account_v1.app.metadata[0].name
}

output "image_pull_secret_name" {
  description = "Name of the image pull secret"
  value       = kubernetes_secret.ghcr.metadata[0].name
}

output "role_name" {
  description = "Name of the RBAC role"
  value       = kubernetes_role.migration_watcher.metadata[0].name
}

output "role_binding_name" {
  description = "Name of the RBAC role binding"
  value       = kubernetes_role_binding.migration_watcher.metadata[0].name
}

output "workload_identity_annotation" {
  description = "Workload Identity annotation on the ServiceAccount"
  value       = kubernetes_service_account_v1.app.metadata[0].annotations["iam.gke.io/gcp-service-account"]
}
