variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "demo-kind"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use"
  type        = string
  default     = "v1.28.0"
}

variable "worker_nodes" {
  description = "Number of worker nodes"
  type        = number
  default     = 0
}

variable "api_server_port" {
  description = "Host port for API server"
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
  description = "Kubernetes namespace for workloads"
  type        = string
  default     = "demo-app"
}

variable "service_account" {
  description = "Kubernetes service account name"
  type        = string
  default     = "demo-sa"
}
