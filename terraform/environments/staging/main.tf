# Baby Names Application - Staging Environment
# Terraform configuration for GCP and Kubernetes infrastructure

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Module 1: GCP Project Setup (APIs, Cloud NAT)
module "gcp_project_setup" {
  source = "../../modules/gcp-project-setup"

  project_id      = var.project_id
  region          = var.region
  network_name    = var.network_name
  nat_router_name = var.nat_router_name
  nat_config_name = var.nat_config_name
}

# Module 2: GKE Autopilot Cluster
module "gke_autopilot" {
  source = "../../modules/gke-autopilot"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region

  network_name    = var.network_name
  subnetwork_name = var.subnetwork_name

  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  master_authorized_networks = var.master_authorized_networks

  release_channel        = var.release_channel
  maintenance_start_time = var.maintenance_start_time
  deletion_protection    = var.cluster_deletion_protection

  labels = var.cluster_labels

  depends_on = [
    module.gcp_project_setup
  ]
}

# Module 3: GCP Service Account (for application workload)
module "gcp_service_account" {
  source = "../../modules/gcp-service-account"

  project_id         = var.project_id
  service_account_id = var.gcp_service_account_id
  display_name       = var.gcp_service_account_display_name
  description        = "Service account for baby-names application in ${var.environment}"

  k8s_namespace            = var.namespace
  k8s_service_account_name = var.k8s_service_account_name

  enable_cloudsql_instance_user_role = true

  depends_on = [
    module.gke_autopilot
  ]
}

# Module 4: CloudSQL PostgreSQL Instance
module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id              = var.project_id
  instance_name           = var.cloudsql_instance_name
  region                  = var.region
  database_version        = var.database_version
  tier                    = var.cloudsql_tier
  availability_type       = var.cloudsql_availability_type
  disk_size               = var.cloudsql_disk_size
  deletion_protection     = var.cloudsql_deletion_protection

  database_name  = var.database_name
  iam_user_email = module.gcp_service_account.service_account_email

  backup_start_time                  = var.backup_start_time
  enable_point_in_time_recovery      = var.enable_point_in_time_recovery
  transaction_log_retention_days     = var.transaction_log_retention_days
  retained_backups                   = var.retained_backups

  maintenance_window_day  = var.maintenance_window_day
  maintenance_window_hour = var.maintenance_window_hour

  enable_public_ip    = var.enable_public_ip
  require_ssl         = var.require_ssl
  authorized_networks = var.authorized_networks

  depends_on = [
    module.gcp_service_account
  ]
}

# Module 5: Kubernetes Namespace and Prerequisites
module "k8s_namespace" {
  source = "../../modules/k8s-namespace"

  namespace_name   = var.namespace
  create_namespace = var.create_namespace
  app_name         = var.app_name

  service_account_name      = var.k8s_service_account_name
  gcp_service_account_email = module.gcp_service_account.service_account_email

  image_pull_secret_name = var.image_pull_secret_name
  registry_server        = var.registry_server
  registry_username      = var.registry_username
  registry_password      = var.registry_password
  registry_email         = var.registry_email

  namespace_labels = var.namespace_labels

  depends_on = [
    module.gke_autopilot,
    module.gcp_service_account
  ]
}

# Module 6: Database Bootstrap (PostgreSQL permissions)
module "database_bootstrap" {
  source = "../../modules/database-bootstrap"

  project_id               = var.project_id
  region                   = var.region
  cloudsql_instance_name   = var.cloudsql_instance_name
  instance_connection_name = module.cloudsql.instance_connection_name

  database_name  = var.database_name
  iam_user_email = module.gcp_service_account.service_account_email

  namespace            = var.namespace
  service_account_name = var.k8s_service_account_name

  temp_pod_name   = var.bootstrap_pod_name
  timeout_seconds = var.bootstrap_timeout_seconds

  depends_on = [
    module.cloudsql,
    module.k8s_namespace
  ]
}
