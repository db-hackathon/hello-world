# Generate kind cluster configuration
resource "local_file" "kind_config" {
  filename = "${path.root}/kind-config.yaml"
  content  = <<-EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: ${var.http_port}
    protocol: TCP
  - containerPort: 443
    hostPort: ${var.https_port}
    protocol: TCP
%{for i in range(var.worker_nodes)}
- role: worker
%{endfor}
networking:
  apiServerPort: ${var.api_server_port}
EOF
}

# Create kind cluster
resource "null_resource" "kind_cluster" {
  depends_on = [local_file.kind_config]

  triggers = {
    config_hash   = local_file.kind_config.content
    cluster_name  = var.cluster_name
  }

  provisioner "local-exec" {
    command = "kind create cluster --name ${var.cluster_name} --image kindest/node:${var.kubernetes_version} --config ${local_file.kind_config.filename}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name ${self.triggers.cluster_name} || true"
  }
}

# Wait for cluster to be ready
resource "null_resource" "wait_for_cluster" {
  depends_on = [null_resource.kind_cluster]

  provisioner "local-exec" {
    command = "kubectl --context kind-${var.cluster_name} wait --for=condition=Ready nodes --all --timeout=120s"
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-${var.cluster_name}"
}

# Create namespace
resource "kubernetes_namespace" "workload" {
  depends_on = [null_resource.wait_for_cluster]

  metadata {
    name = var.namespace
  }
}

# Create service account
resource "kubernetes_service_account" "workload" {
  depends_on = [kubernetes_namespace.workload]

  metadata {
    name      = var.service_account
    namespace = var.namespace
  }
}

# Create ClusterRoleBinding for service account
resource "kubernetes_cluster_role_binding" "workload" {
  depends_on = [kubernetes_service_account.workload]

  metadata {
    name = "${var.service_account}-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.service_account
    namespace = var.namespace
  }
}

# Create token secret for service account (K8s 1.24+)
resource "kubernetes_secret" "sa_token" {
  depends_on = [kubernetes_service_account.workload]

  metadata {
    name      = "${var.service_account}-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = var.service_account
    }
  }

  type = "kubernetes.io/service-account-token"
}

# Export admin kubeconfig to file
resource "local_file" "kubeconfig" {
  depends_on = [null_resource.kind_cluster]

  filename = "${path.root}/${var.cluster_name}-kubeconfig.yaml"

  content = <<-EOF
# Generated kubeconfig for kind cluster ${var.cluster_name}
#
# To use this kubeconfig:
#   export KUBECONFIG=${path.root}/${var.cluster_name}-kubeconfig.yaml
#   kubectl get nodes
#
# Or merge with your existing kubeconfig:
#   KUBECONFIG=~/.kube/config:${path.root}/${var.cluster_name}-kubeconfig.yaml kubectl config view --flatten > ~/.kube/config.new
#   mv ~/.kube/config.new ~/.kube/config

EOF

  provisioner "local-exec" {
    command = "kind get kubeconfig --name ${var.cluster_name} >> ${self.filename}"
  }
}

# Generate service account kubeconfig
resource "null_resource" "sa_kubeconfig" {
  depends_on = [
    kubernetes_secret.sa_token,
    local_file.kubeconfig
  ]

  triggers = {
    cluster_name    = var.cluster_name
    namespace       = var.namespace
    service_account = var.service_account
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Extract SA token and CA cert
      TOKEN=$(kubectl --context kind-${var.cluster_name} get secret ${var.service_account}-token -n ${var.namespace} -o jsonpath='{.data.token}' | base64 -d)
      CA_CERT=$(kubectl --context kind-${var.cluster_name} get secret ${var.service_account}-token -n ${var.namespace} -o jsonpath='{.data.ca\.crt}')
      SERVER=$(kubectl --context kind-${var.cluster_name} config view --minify -o jsonpath='{.clusters[0].cluster.server}')

      # Generate SA kubeconfig
      cat > ${path.root}/${var.cluster_name}-sa-kubeconfig.yaml <<EOF
      apiVersion: v1
      kind: Config
      clusters:
      - name: ${var.cluster_name}
        cluster:
          certificate-authority-data: $CA_CERT
          server: $SERVER
      contexts:
      - name: ${var.service_account}@${var.cluster_name}
        context:
          cluster: ${var.cluster_name}
          namespace: ${var.namespace}
          user: ${var.service_account}
      current-context: ${var.service_account}@${var.cluster_name}
      users:
      - name: ${var.service_account}
        user:
          token: $TOKEN
      EOF
    EOT
  }
}
