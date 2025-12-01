# Provider Configurations for Test Environment
# Uses gcloud application-default credentials

# Google Cloud Provider
# Authenticates using: gcloud auth application-default login
provider "google" {
  project = var.project_id
  region  = var.region
}

# Get Google Cloud client configuration for Kubernetes provider
data "google_client_config" "default" {}

# Get GKE cluster details for Kubernetes provider
data "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  depends_on = [module.gke_autopilot]
}

# Kubernetes Provider
# Authenticates to GKE cluster using gcloud credentials
provider "kubernetes" {
  host  = "https://${data.google_container_cluster.primary.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  )
}
