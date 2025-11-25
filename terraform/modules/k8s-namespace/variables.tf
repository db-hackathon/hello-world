variable "namespace_name" {
  description = "Name of the Kubernetes namespace"
  type        = string
}

variable "create_namespace" {
  description = "Whether to create the namespace (set to false if Helm creates it)"
  type        = bool
  default     = true
}

variable "namespace_labels" {
  description = "Additional labels for the namespace"
  type        = map(string)
  default     = {}
}

variable "namespace_annotations" {
  description = "Additional annotations for the namespace"
  type        = map(string)
  default     = {}
}

variable "app_name" {
  description = "Application name for labels"
  type        = string
  default     = "baby-names"
}

# ServiceAccount configuration
variable "service_account_name" {
  description = "Name of the Kubernetes ServiceAccount"
  type        = string
}

variable "gcp_service_account_email" {
  description = "Email of the GCP service account for Workload Identity"
  type        = string
}

# ImagePullSecret configuration
variable "image_pull_secret_name" {
  description = "Name of the image pull secret"
  type        = string
  default     = "ghcr-secret"
}

variable "registry_server" {
  description = "Container registry server"
  type        = string
  default     = "ghcr.io"
}

variable "registry_username" {
  description = "Container registry username"
  type        = string
}

variable "registry_password" {
  description = "Container registry password/token"
  type        = string
  sensitive   = true
}

variable "registry_email" {
  description = "Container registry email"
  type        = string
  default     = "noreply@github.com"
}

# Helm integration
variable "helm_release_name" {
  description = "Name of the Helm release that will manage these resources"
  type        = string
  default     = ""
}

variable "add_helm_annotations" {
  description = "Whether to add Helm annotations for adoption by Helm charts"
  type        = bool
  default     = false
}
