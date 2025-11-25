# Kubernetes Namespace Module
# Creates namespace, service account, RBAC, and image pull secrets

terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

# Create namespace (optional - can be created by Helm instead)
resource "kubernetes_namespace" "app" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace_name

    labels = merge(
      {
        "app.kubernetes.io/name"       = var.app_name
        "app.kubernetes.io/managed-by" = var.add_helm_annotations ? "Helm" : "terraform"
      },
      var.namespace_labels
    )

    annotations = merge(
      var.add_helm_annotations && var.helm_release_name != "" ? {
        "meta.helm.sh/release-name"      = var.helm_release_name
        "meta.helm.sh/release-namespace" = var.namespace_name
      } : {},
      var.namespace_annotations
    )
  }
}

locals {
  namespace = var.create_namespace ? kubernetes_namespace.app[0].metadata[0].name : var.namespace_name
}

# Create ImagePullSecret for GitHub Container Registry
resource "kubernetes_secret" "ghcr" {
  metadata {
    name      = var.image_pull_secret_name
    namespace = local.namespace

    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/managed-by" = var.add_helm_annotations ? "Helm" : "terraform"
    }

    annotations = var.add_helm_annotations && var.helm_release_name != "" ? {
      "meta.helm.sh/release-name"      = var.helm_release_name
      "meta.helm.sh/release-namespace" = var.namespace_name
    } : {}
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.registry_server}" = {
          username = var.registry_username
          password = var.registry_password
          email    = var.registry_email
          auth     = base64encode("${var.registry_username}:${var.registry_password}")
        }
      }
    })
  }

  depends_on = [kubernetes_namespace.app]
}

# Create Kubernetes ServiceAccount with Workload Identity annotation and ImagePullSecret
resource "kubernetes_service_account_v1" "app" {
  metadata {
    name      = var.service_account_name
    namespace = local.namespace

    annotations = merge(
      {
        "iam.gke.io/gcp-service-account" = var.gcp_service_account_email
      },
      var.add_helm_annotations && var.helm_release_name != "" ? {
        "meta.helm.sh/release-name"      = var.helm_release_name
        "meta.helm.sh/release-namespace" = var.namespace_name
      } : {}
    )

    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/managed-by" = var.add_helm_annotations ? "Helm" : "terraform"
    }
  }

  image_pull_secret {
    name = kubernetes_secret.ghcr.metadata[0].name
  }

  depends_on = [
    kubernetes_namespace.app,
    kubernetes_secret.ghcr
  ]
}

# Create RBAC Role for migration watcher
# Allows init containers to query migration pod/job status
resource "kubernetes_role" "migration_watcher" {
  metadata {
    name      = "migration-watcher"
    namespace = local.namespace

    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/component"  = "rbac"
      "app.kubernetes.io/managed-by" = var.add_helm_annotations ? "Helm" : "terraform"
    }

    annotations = var.add_helm_annotations && var.helm_release_name != "" ? {
      "meta.helm.sh/release-name"      = var.helm_release_name
      "meta.helm.sh/release-namespace" = var.namespace_name
    } : {}
  }

  # Permissions to watch pods
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  # Permissions to watch jobs
  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [kubernetes_namespace.app]
}

# Create RBAC RoleBinding
resource "kubernetes_role_binding" "migration_watcher" {
  metadata {
    name      = "migration-watcher-binding"
    namespace = local.namespace

    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/component"  = "rbac"
      "app.kubernetes.io/managed-by" = var.add_helm_annotations ? "Helm" : "terraform"
    }

    annotations = var.add_helm_annotations && var.helm_release_name != "" ? {
      "meta.helm.sh/release-name"      = var.helm_release_name
      "meta.helm.sh/release-namespace" = var.namespace_name
    } : {}
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.migration_watcher.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.service_account_name
    namespace = local.namespace
  }

  depends_on = [
    kubernetes_role.migration_watcher,
    kubernetes_service_account_v1.app
  ]
}
