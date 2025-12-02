# Baby Names Application - Test Environment Variables
# Test deployment with distinct resource names to avoid conflicts

# General Configuration
project_id  = "extended-ascent-477308-m8"
region      = "europe-west1"
environment = "test"
app_name    = "baby-names"

# Network Configuration
network_name    = "default"
subnetwork_name = "default"

# NAT Configuration - Reuse existing NAT from staging (GCP only allows one NAT per network/region)
create_nat      = false
nat_router_name = "nat-router" # Reference to existing NAT router from staging
nat_config_name = "nat-config" # Reference to existing NAT config from staging

# GKE Cluster Configuration
cluster_name                = "baby-names-test3" # Different from staging (hellow-world-manual)
master_ipv4_cidr_block      = "172.16.2.0/28"    # Different CIDR from staging and test
release_channel             = "REGULAR"
maintenance_start_time      = "03:00"
cluster_deletion_protection = false # Easier to destroy for testing

# Master authorized networks (allows all for testing)
master_authorized_networks = []

cluster_labels = {
  environment = "test"
  app         = "baby-names"
  managed-by  = "terraform"
  purpose     = "terraform-validation"
}

# GCP Service Account Configuration
gcp_service_account_id           = "bn-test3" # Shortened to fit CloudSQL 63-char limit
gcp_service_account_display_name = "Baby Names Application - Test3"

# CloudSQL Configuration
cloudsql_instance_name       = "baby-names-test3" # Different from staging and test
database_version             = "POSTGRES_17"
cloudsql_tier                = "db-custom-1-3840" # Smaller tier for testing (1 vCPU, 3.75GB)
cloudsql_availability_type   = "ZONAL"
cloudsql_disk_size           = 10
cloudsql_deletion_protection = false # Easier to destroy for testing
database_name                = "baby_names"

# Backup Configuration (minimal for testing)
backup_start_time              = "03:00"
enable_point_in_time_recovery  = false # Disabled for testing
transaction_log_retention_days = 7
retained_backups               = 3 # Fewer backups for testing
maintenance_window_day         = 7 # Sunday
maintenance_window_hour        = 3 # 3 AM

# Network Configuration for CloudSQL
enable_public_ip    = true
require_ssl         = false # IAM auth provides security
authorized_networks = []

# Kubernetes Namespace Configuration
namespace                = "baby-names-test3" # Different from staging and test
create_namespace         = true
k8s_service_account_name = "baby-names-test3" # Different from staging and test

namespace_labels = {
  environment = "test"
  app         = "baby-names"
  managed-by  = "terraform"
  purpose     = "terraform-validation"
}

# Note: Container registry secrets removed - GKE uses Workload Identity to access GAR
# The GCP service account has roles/artifactregistry.reader for image pulling

# Database Bootstrap Configuration
bootstrap_pod_name        = "psql-client-terraform-test3"
bootstrap_timeout_seconds = 600 # Increased from 300s for GKE Autopilot node scaling
