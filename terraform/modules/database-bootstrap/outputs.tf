output "bootstrap_completed" {
  description = "Indicates that database permissions bootstrap has completed"
  value       = true
  depends_on  = [null_resource.database_permissions]
}

output "iam_database_user" {
  description = "PostgreSQL username for the IAM user (already formatted with .iam suffix)"
  value       = var.iam_user_email # Already formatted by upstream module
}

output "database_name" {
  description = "Name of the bootstrapped database"
  value       = var.database_name
}
