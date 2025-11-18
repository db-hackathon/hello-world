output "connection_info" {
  description = "Connection information for the kind cluster"
  value = {
    cluster_name           = module.kind_cluster.cluster_name
    cluster_endpoint       = module.kind_cluster.cluster_endpoint
    kubeconfig_path        = module.kind_cluster.kubeconfig_path
    kubeconfig_context     = module.kind_cluster.kubeconfig_context
    sa_kubeconfig_path     = module.kind_cluster.service_account_kubeconfig_path
    namespace              = module.kind_cluster.namespace
    service_account        = module.kind_cluster.service_account
    networking_details     = module.kind_cluster.networking_details
  }
}

output "quick_start" {
  description = "Quick start commands"
  value = <<-EOT

    ✓ kind cluster deployed successfully!

    Cluster Name: ${module.kind_cluster.cluster_name}
    Cluster Endpoint: ${module.kind_cluster.cluster_endpoint}
    Kubectl Context: ${module.kind_cluster.kubeconfig_context}

    Admin Access:
      export KUBECONFIG=${module.kind_cluster.kubeconfig_path}
      kubectl get nodes
      kubectl get pods -A

    OR use the context directly:
      kubectl --context ${module.kind_cluster.kubeconfig_context} get nodes

    Service Account Access (namespace: ${module.kind_cluster.namespace}):
      export KUBECONFIG=${module.kind_cluster.service_account_kubeconfig_path}
      kubectl get pods -n ${module.kind_cluster.namespace}

    Access services:
      HTTP:  http://localhost:${module.kind_cluster.networking_details.http_port}
      HTTPS: https://localhost:${module.kind_cluster.networking_details.https_port}

    Cleanup:
      terraform destroy

  EOT
}
