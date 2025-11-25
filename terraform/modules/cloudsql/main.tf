# CloudSQL Module
# Creates CloudSQL PostgreSQL instance with IAM authentication enabled

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Local variables
locals {
  # CloudSQL IAM user names must not include the .gserviceaccount.com suffix
  # Convert: user@project.iam.gserviceaccount.com -> user@project.iam
  cloudsql_iam_user_name = replace(var.iam_user_email, ".gserviceaccount.com", "")
}

# Random suffix for instance name (if needed for recreations)
resource "random_id" "db_name_suffix" {
  count       = var.use_random_suffix ? 1 : 0
  byte_length = 4
}

locals {
  instance_name = var.use_random_suffix ? "${var.instance_name}-${random_id.db_name_suffix[0].hex}" : var.instance_name
}

# CloudSQL PostgreSQL instance
resource "google_sql_database_instance" "main" {
  name             = local.instance_name
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  # Deletion protection
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_type         = var.disk_type
    disk_size         = var.disk_size
    disk_autoresize   = var.disk_autoresize

    # CRITICAL: Enable IAM authentication
    # Without this flag, IAM-based login will fail
    # WARNING: Changing this flag triggers instance restart
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    # Backup configuration
    backup_configuration {
      enabled                        = true
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.enable_point_in_time_recovery
      transaction_log_retention_days = var.transaction_log_retention_days

      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }

    # Maintenance window
    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_update_track
    }

    # IP configuration
    ip_configuration {
      ipv4_enabled    = var.enable_public_ip
      private_network = var.private_network
      require_ssl     = var.require_ssl

      # Authorized networks (if public IP is enabled)
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.cidr
        }
      }
    }

    # Insights configuration
    insights_config {
      query_insights_enabled  = var.enable_query_insights
      query_plans_per_minute  = var.query_plans_per_minute
      query_string_length     = var.query_string_length
      record_application_tags = var.record_application_tags
    }
  }

  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false # Set to true in production

    # Ignore changes to database_flags to avoid unnecessary restarts
    # Remove this if you need to modify flags
    ignore_changes = [
      settings[0].database_flags
    ]
  }
}

# Create database
resource "google_sql_database" "baby_names" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

# Create CloudSQL IAM database user
# This creates the authentication layer; PostgreSQL permissions must be granted separately
resource "google_sql_user" "iam_user" {
  name     = local.cloudsql_iam_user_name
  instance = google_sql_database_instance.main.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
  project  = var.project_id
}

# Note: PostgreSQL GRANT statements cannot be managed by Terraform google_sql_user
# Use the database-bootstrap module to grant permissions via psql
