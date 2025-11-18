terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Deploy kind cluster using local implementation
module "kind_cluster" {
  source = "../"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  worker_nodes       = var.worker_nodes

  namespace       = var.namespace
  service_account = var.service_account

  api_server_port = var.api_server_port
  http_port       = var.http_port
  https_port      = var.https_port
}
