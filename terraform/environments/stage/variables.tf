# General Configuration
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for regional resources"
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Environment name (staging, production, etc.)"
  type        = string
  default     = "staging"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "baby-names"
}

# Network Configuration
variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "Subnetwork name"
  type        = string
  default     = "default"
}

variable "create_nat" {
  description = "Whether to create Cloud NAT resources"
  type        = bool
  default     = true
}

variable "nat_router_name" {
  description = "Cloud Router name for NAT"
  type        = string
  default     = "nat-router"
}

variable "nat_config_name" {
  description = "Cloud NAT configuration name"
  type        = string
  default     = "nat-config"
}

# GKE Cluster Configuration
variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "IP CIDR block for Kubernetes master (must be /28)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to access Kubernetes API"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "maintenance_start_time" {
  description = "Maintenance window start time (HH:MM)"
  type        = string
  default     = "03:00"
}

variable "cluster_deletion_protection" {
  description = "Enable deletion protection for GKE cluster"
  type        = bool
  default     = true
}

variable "cluster_labels" {
  description = "Labels for GKE cluster"
  type        = map(string)
  default     = {}
}

# GCP Service Account Configuration
variable "gcp_service_account_id" {
  description = "GCP service account ID (the part before @)"
  type        = string
}

variable "gcp_service_account_display_name" {
  description = "Display name for GCP service account"
  type        = string
  default     = "Baby Names Application - Staging"
}

# CloudSQL Configuration
variable "cloudsql_instance_name" {
  description = "CloudSQL instance name"
  type        = string
}

variable "database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_17"
}

variable "cloudsql_tier" {
  description = "CloudSQL machine tier"
  type        = string
  default     = "db-custom-2-8192"
}

variable "cloudsql_availability_type" {
  description = "CloudSQL availability type (ZONAL or REGIONAL)"
  type        = string
  default     = "ZONAL"
}

variable "cloudsql_disk_size" {
  description = "CloudSQL disk size in GB"
  type        = number
  default     = 10
}

variable "cloudsql_deletion_protection" {
  description = "Enable deletion protection for CloudSQL"
  type        = bool
  default     = true
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "baby_names"
}

# Backup Configuration
variable "backup_start_time" {
  description = "Backup start time (HH:MM)"
  type        = string
  default     = "03:00"
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "transaction_log_retention_days" {
  description = "Transaction log retention days"
  type        = number
  default     = 7
}

variable "retained_backups" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

variable "maintenance_window_day" {
  description = "Maintenance window day (1-7, 1=Monday)"
  type        = number
  default     = 7
}

variable "maintenance_window_hour" {
  description = "Maintenance window hour (0-23)"
  type        = number
  default     = 3
}

# Network Configuration for CloudSQL
variable "enable_public_ip" {
  description = "Enable public IP for CloudSQL"
  type        = bool
  default     = true
}

variable "require_ssl" {
  description = "Require SSL for CloudSQL connections"
  type        = bool
  default     = false
}

variable "authorized_networks" {
  description = "Authorized networks for CloudSQL public IP"
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

# Kubernetes Namespace Configuration
variable "namespace" {
  description = "Kubernetes namespace name"
  type        = string
}

variable "create_namespace" {
  description = "Whether to create the namespace (set false if Helm creates it)"
  type        = bool
  default     = true
}

variable "namespace_labels" {
  description = "Labels for Kubernetes namespace"
  type        = map(string)
  default     = {}
}

variable "k8s_service_account_name" {
  description = "Kubernetes ServiceAccount name"
  type        = string
}

# Note: Container registry secrets removed - GKE uses Workload Identity to access GAR
# The GCP service account has roles/artifactregistry.reader for image pulling

# Database Bootstrap Configuration
variable "bootstrap_pod_name" {
  description = "Name of temporary pod for database bootstrap"
  type        = string
  default     = "psql-client-terraform"
}

variable "bootstrap_timeout_seconds" {
  description = "Timeout for database bootstrap in seconds"
  type        = number
  default     = 300
}
