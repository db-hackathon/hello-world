variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for regional resources"
  type        = string
  default     = "europe-west1"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "default"
}

variable "create_nat" {
  description = "Whether to create Cloud NAT resources (set to false to reuse existing NAT)"
  type        = bool
  default     = true
}

variable "nat_router_name" {
  description = "Name of the Cloud Router for NAT"
  type        = string
  default     = "nat-router"
}

variable "nat_config_name" {
  description = "Name of the Cloud NAT configuration"
  type        = string
  default     = "nat-config"
}

variable "nat_source_subnetwork_ip_ranges" {
  description = "How to assign IPs for NAT (ALL_SUBNETWORKS_ALL_IP_RANGES or LIST_OF_SUBNETWORKS)"
  type        = string
  default     = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  validation {
    condition     = contains(["ALL_SUBNETWORKS_ALL_IP_RANGES", "LIST_OF_SUBNETWORKS"], var.nat_source_subnetwork_ip_ranges)
    error_message = "Must be either ALL_SUBNETWORKS_ALL_IP_RANGES or LIST_OF_SUBNETWORKS"
  }
}

variable "nat_subnetworks" {
  description = "List of subnetwork self-links for NAT (required when nat_source_subnetwork_ip_ranges is LIST_OF_SUBNETWORKS)"
  type = list(object({
    name                     = string
    source_ip_ranges_to_nat  = list(string)
    secondary_ip_range_names = list(string)
  }))
  default = []
}
