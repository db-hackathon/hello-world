variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster (regional cluster)"
  type        = string
  default     = "europe-west1"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "Name of the subnetwork"
  type        = string
  default     = "default"
}

variable "cluster_ipv4_cidr_block" {
  description = "IP CIDR block for pods (leave empty for auto-allocation)"
  type        = string
  default     = ""
}

variable "services_ipv4_cidr_block" {
  description = "IP CIDR block for services (leave empty for auto-allocation)"
  type        = string
  default     = ""
}

variable "master_ipv4_cidr_block" {
  description = "IP CIDR block for the Kubernetes master (must be /28)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks allowed to access the Kubernetes master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "release_channel" {
  description = "Release channel for automatic GKE updates (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "maintenance_start_time" {
  description = "Start time for daily maintenance window (HH:MM format)"
  type        = string
  default     = "03:00"
}

variable "autoscaling_profile" {
  description = "Autoscaling profile (BALANCED or OPTIMIZE_UTILIZATION)"
  type        = string
  default     = "BALANCED"
}

variable "enable_managed_prometheus" {
  description = "Enable Google Cloud Managed Service for Prometheus (always enabled in Autopilot clusters version 1.25+)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection for the cluster"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to the cluster"
  type        = map(string)
  default     = {}
}
