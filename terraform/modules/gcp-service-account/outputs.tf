output "service_account_email" {
  description = "Email address of the service account"
  value       = google_service_account.app.email
}

output "service_account_name" {
  description = "Fully qualified name of the service account"
  value       = google_service_account.app.name
}

output "service_account_id" {
  description = "Service account ID"
  value       = google_service_account.app.account_id
}

output "workload_identity_member" {
  description = "Workload Identity member string for Kubernetes ServiceAccount annotation"
  value       = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account_name}]"
}

output "cloudsql_iam_user" {
  description = "CloudSQL IAM database user name (format: user@project.iam)"
  value       = replace(google_service_account.app.email, ".gserviceaccount.com", "")
}
