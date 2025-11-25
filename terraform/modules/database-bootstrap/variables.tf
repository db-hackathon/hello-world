variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "cloudsql_instance_name" {
  description = "Name of the CloudSQL instance"
  type        = string
}

variable "instance_connection_name" {
  description = "CloudSQL instance connection name (project:region:instance)"
  type        = string
}

variable "database_name" {
  description = "Name of the database"
  type        = string
}

variable "iam_user_email" {
  description = "Email of the IAM service account that needs database permissions"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where temporary pod will be created"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name for the temporary pod"
  type        = string
}

variable "temp_pod_name" {
  description = "Name of the temporary pod for database setup"
  type        = string
  default     = "psql-client-terraform"
}

variable "timeout_seconds" {
  description = "Timeout in seconds for pod readiness and SQL execution"
  type        = number
  default     = 300
}
