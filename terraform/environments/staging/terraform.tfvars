# Baby Names Application - Staging Environment Variables
# Based on the existing infrastructure documented in INFRASTRUCTURE_STATE.md

# General Configuration
project_id  = "extended-ascent-477308-m8"
region      = "europe-west1"
environment = "staging"
app_name    = "baby-names"

# Network Configuration
network_name    = "default"
subnetwork_name = "default"
nat_router_name = "nat-router"
nat_config_name = "nat-config"

# GKE Cluster Configuration
cluster_name              = "hellow-world-manual"
master_ipv4_cidr_block    = "172.16.0.0/28"
release_channel           = "REGULAR"
maintenance_start_time    = "03:00"
cluster_deletion_protection = true

# Master authorized networks (optional - allows all by default)
master_authorized_networks = [
  # {
  #   cidr_block   = "0.0.0.0/0"
  #   display_name = "All networks"
  # }
]

cluster_labels = {
  environment = "staging"
  app         = "baby-names"
  managed-by  = "terraform"
}

# GCP Service Account Configuration
gcp_service_account_id           = "hello-world-staging"
gcp_service_account_display_name = "Baby Names Application - Staging"

# CloudSQL Configuration
cloudsql_instance_name      = "hello-world-manual"
database_version            = "POSTGRES_17"
cloudsql_tier               = "db-custom-2-8192"
cloudsql_availability_type  = "ZONAL"
cloudsql_disk_size          = 10
cloudsql_deletion_protection = true
database_name               = "baby_names"

# Backup Configuration
backup_start_time                  = "03:00"
enable_point_in_time_recovery      = true
transaction_log_retention_days     = 7
retained_backups                   = 7
maintenance_window_day             = 7  # Sunday
maintenance_window_hour            = 3  # 3 AM

# Network Configuration for CloudSQL
enable_public_ip = true
require_ssl      = false  # IAM auth provides security
authorized_networks = [
  # Add authorized networks if needed
  # {
  #   name = "office"
  #   cidr = "1.2.3.4/32"
  # }
]

# Kubernetes Namespace Configuration
namespace                = "baby-names-staging"
create_namespace         = true  # Terraform creates namespace (not Helm)
k8s_service_account_name = "baby-names-staging"

namespace_labels = {
  environment = "staging"
  app         = "baby-names"
  managed-by  = "terraform"
}

# Container Registry Configuration
# Note: registry_username and registry_password should be set via:
# - Terraform Cloud/Enterprise variables (recommended)
# - Environment variables: TF_VAR_registry_username, TF_VAR_registry_password
# - Command line: terraform apply -var="registry_username=..." -var="registry_password=..."

registry_username = "andrewesweet"
# registry_password = "<SET_VIA_TF_CLOUD_OR_ENV_VAR>"  # GitHub PAT with read:packages scope
registry_server   = "ghcr.io"
registry_email    = "noreply@github.com"

# Database Bootstrap Configuration
bootstrap_pod_name       = "psql-client-terraform"
bootstrap_timeout_seconds = 300
