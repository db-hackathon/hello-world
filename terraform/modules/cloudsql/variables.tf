variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "instance_name" {
  description = "Name of the CloudSQL instance"
  type        = string
}

variable "use_random_suffix" {
  description = "Add random suffix to instance name (useful for testing/recreation)"
  type        = bool
  default     = false
}

variable "database_version" {
  description = "PostgreSQL version (e.g., POSTGRES_17, POSTGRES_15)"
  type        = string
  default     = "POSTGRES_17"
}

variable "region" {
  description = "GCP region for the instance"
  type        = string
  default     = "europe-west1"
}

variable "tier" {
  description = "Machine tier (e.g., db-custom-2-8192)"
  type        = string
  default     = "db-custom-2-8192"
}

variable "availability_type" {
  description = "Availability type (ZONAL or REGIONAL)"
  type        = string
  default     = "ZONAL"
}

variable "disk_type" {
  description = "Disk type (PD_SSD or PD_HDD)"
  type        = string
  default     = "PD_SSD"
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 10
}

variable "disk_autoresize" {
  description = "Enable automatic disk size increase"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection for the instance"
  type        = bool
  default     = true
}

# Backup configuration
variable "backup_start_time" {
  description = "Start time for daily backups (HH:MM format)"
  type        = string
  default     = "03:00"
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery (transaction logs)"
  type        = bool
  default     = true
}

variable "transaction_log_retention_days" {
  description = "Transaction log retention in days"
  type        = number
  default     = 7
}

variable "retained_backups" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

# Maintenance window
variable "maintenance_window_day" {
  description = "Day of week for maintenance (1-7, 1=Monday)"
  type        = number
  default     = 7 # Sunday
}

variable "maintenance_window_hour" {
  description = "Hour of day for maintenance (0-23)"
  type        = number
  default     = 3
}

variable "maintenance_update_track" {
  description = "Maintenance update track (stable or canary)"
  type        = string
  default     = "stable"
}

# Network configuration
variable "enable_public_ip" {
  description = "Enable public IP address"
  type        = bool
  default     = true
}

variable "private_network" {
  description = "VPC network for private IP (format: projects/{project}/global/networks/{network})"
  type        = string
  default     = null
}

variable "require_ssl" {
  description = "Require SSL for connections"
  type        = bool
  default     = false
}

variable "authorized_networks" {
  description = "List of authorized networks for public IP access"
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

# Query insights
variable "enable_query_insights" {
  description = "Enable query insights"
  type        = bool
  default     = false
}

variable "query_plans_per_minute" {
  description = "Number of query plans to sample per minute"
  type        = number
  default     = 5
}

variable "query_string_length" {
  description = "Maximum query string length to store"
  type        = number
  default     = 1024
}

variable "record_application_tags" {
  description = "Record application tags in query insights"
  type        = bool
  default     = false
}

# Database and user
variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "baby_names"
}

variable "iam_user_email" {
  description = "Email of the IAM service account for database access"
  type        = string
}
