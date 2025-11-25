output "instance_name" {
  description = "Name of the CloudSQL instance"
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "Connection name for Cloud SQL Proxy (project:region:instance)"
  value       = google_sql_database_instance.main.connection_name
}

output "instance_self_link" {
  description = "Self link of the CloudSQL instance"
  value       = google_sql_database_instance.main.self_link
}

output "instance_ip_addresses" {
  description = "IP addresses of the instance"
  value       = google_sql_database_instance.main.ip_address
}

output "public_ip_address" {
  description = "Public IP address of the instance"
  value       = length(google_sql_database_instance.main.ip_address) > 0 ? google_sql_database_instance.main.ip_address[0].ip_address : null
}

output "database_version" {
  description = "PostgreSQL version"
  value       = google_sql_database_instance.main.database_version
}

output "database_name" {
  description = "Name of the created database"
  value       = google_sql_database.baby_names.name
}

output "iam_user_name" {
  description = "Name of the IAM database user"
  value       = google_sql_user.iam_user.name
}

output "iam_database_user" {
  description = "Full IAM database user name (for DB_USER environment variable)"
  value       = local.cloudsql_iam_user_name
}

output "region" {
  description = "Region of the instance"
  value       = google_sql_database_instance.main.region
}

output "tier" {
  description = "Machine tier of the instance"
  value       = google_sql_database_instance.main.settings[0].tier
}
