output "cluster_name" {
  description = "Name of the kind cluster"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = "https://127.0.0.1:${var.api_server_port}"
}

output "kubeconfig_path" {
  description = "Path to admin kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "kubeconfig_context" {
  description = "kubectl context name for this cluster"
  value       = "kind-${var.cluster_name}"
}

output "namespace" {
  description = "Kubernetes namespace created for workloads"
  value       = kubernetes_namespace.workload.metadata[0].name
}

output "service_account" {
  description = "Kubernetes service account name for workload identity"
  value       = kubernetes_service_account.workload.metadata[0].name
}

output "service_account_kubeconfig_path" {
  description = "Path to service account kubeconfig file"
  value       = "${path.root}/${var.cluster_name}-sa-kubeconfig.yaml"
}

output "networking_details" {
  description = "Networking information for the cluster"
  value = {
    api_server_port = var.api_server_port
    http_port       = var.http_port
    https_port      = var.https_port
    network_mode    = "Docker bridge"
    cluster_nodes   = 1 + var.worker_nodes
  }
}
