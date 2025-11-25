variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID (the part before @)"
  type        = string
}

variable "display_name" {
  description = "Display name for the service account"
  type        = string
  default     = ""
}

variable "description" {
  description = "Description of the service account"
  type        = string
  default     = "Application workload service account for CloudSQL access"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for Workload Identity binding"
  type        = string
}

variable "k8s_service_account_name" {
  description = "Kubernetes ServiceAccount name for Workload Identity binding"
  type        = string
}

variable "enable_cloudsql_instance_user_role" {
  description = "Enable Cloud SQL Instance User role (required for IAM authentication)"
  type        = bool
  default     = true
}
