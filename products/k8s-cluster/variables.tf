variable "venue" {
  description = "Deployment venue: 'public-cloud' (GKE) or 'private-cloud' (k3s on VM)"
  type        = string
  default     = "private-cloud"

  validation {
    condition     = contains(["public-cloud", "private-cloud"], var.venue)
    error_message = "Venue must be either 'public-cloud' or 'private-cloud'."
  }
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VM access (used by private-cloud venue)"
  type        = string
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

# Private cloud (k3s) specific variables
variable "k3s_version" {
  description = "K3s version to install (used by private-cloud venue)"
  type        = string
  default     = "v1.28.5+k3s1"
}

variable "server_memory" {
  description = "Server node memory in MB (used by private-cloud venue)"
  type        = number
  default     = 2048
}

variable "server_vcpu" {
  description = "Server node vCPU count (used by private-cloud venue)"
  type        = number
  default     = 2
}

# Public cloud (GKE) specific variables (for future implementation)
# variable "gke_region" {
#   description = "GCP region for GKE cluster (used by public-cloud venue)"
#   type        = string
#   default     = "us-central1"
# }
#
# variable "node_count" {
#   description = "Number of nodes in GKE cluster (used by public-cloud venue)"
#   type        = number
#   default     = 3
# }
