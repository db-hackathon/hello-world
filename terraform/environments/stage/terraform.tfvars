# Baby Names Application - Stage Environment Variables
# Staging deployment with distinct resource names

# General Configuration
project_id  = "extended-ascent-477308-m8"
region      = "europe-west1"
environment = "stage"
app_name    = "baby-names"

# Network Configuration
network_name    = "default"
subnetwork_name = "default"

# NAT Configuration - Reuse existing NAT (GCP only allows one NAT per network/region)
create_nat      = false
nat_router_name = "nat-router" # Reference to existing NAT router
nat_config_name = "nat-config" # Reference to existing NAT config

# GKE Cluster Configuration
cluster_name                = "baby-names-stage"
master_ipv4_cidr_block      = "172.16.0.0/28"
release_channel             = "REGULAR"
maintenance_start_time      = "03:00"
cluster_deletion_protection = false # Allow destruction for staging

# Master authorized networks (allows all for staging)
master_authorized_networks = []

cluster_labels = {
  environment = "stage"
  app         = "baby-names"
  managed-by  = "terraform"
  purpose     = "staging"
}

# GCP Service Account Configuration
gcp_service_account_id           = "bn-stage" # Shortened to fit CloudSQL 63-char limit
gcp_service_account_display_name = "Baby Names Application - Stage"

# CloudSQL Configuration
cloudsql_instance_name       = "baby-names-stage"
database_version             = "POSTGRES_17"
cloudsql_tier                = "db-custom-1-3840" # Smaller tier for staging (1 vCPU, 3.75GB)
cloudsql_availability_type   = "ZONAL"
cloudsql_disk_size           = 10
cloudsql_deletion_protection = false # Allow destruction for staging
database_name                = "baby_names"

# Backup Configuration
backup_start_time              = "03:00"
enable_point_in_time_recovery  = false
transaction_log_retention_days = 7
retained_backups               = 3
maintenance_window_day         = 7 # Sunday
maintenance_window_hour        = 3 # 3 AM

# Network Configuration for CloudSQL
enable_public_ip    = true
require_ssl         = false # IAM auth provides security
authorized_networks = []

# Kubernetes Namespace Configuration
namespace                = "baby-names-stage"
create_namespace         = true
k8s_service_account_name = "baby-names-stage"

namespace_labels = {
  environment = "stage"
  app         = "baby-names"
  managed-by  = "terraform"
  purpose     = "staging"
}

# Note: Container registry secrets removed - GKE uses Workload Identity to access GAR
# The GCP service account has roles/artifactregistry.reader for image pulling

# Database Bootstrap Configuration
bootstrap_pod_name        = "psql-client-terraform-stage"
bootstrap_timeout_seconds = 600 # Increased for GKE Autopilot node scaling
