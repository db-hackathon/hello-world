variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "kind-local"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use (e.g., v1.28.0)"
  type        = string
  default     = "v1.28.0"
}

variable "worker_nodes" {
  description = "Number of worker nodes (0 for single-node cluster)"
  type        = number
  default     = 0

  validation {
    condition     = var.worker_nodes >= 0 && var.worker_nodes <= 5
    error_message = "Worker nodes must be between 0 and 5."
  }
}

variable "api_server_port" {
  description = "Host port for Kubernetes API server"
  type        = number
  default     = 6443
}

variable "http_port" {
  description = "Host port for HTTP ingress"
  type        = number
  default     = 8080
}

variable "https_port" {
  description = "Host port for HTTPS ingress"
  type        = number
  default     = 8443
}

variable "namespace" {
  description = "Kubernetes namespace to create for workloads"
  type        = string
  default     = "default"
}

variable "service_account" {
  description = "Kubernetes service account name for workload identity"
  type        = string
  default     = "workload-sa"
}
