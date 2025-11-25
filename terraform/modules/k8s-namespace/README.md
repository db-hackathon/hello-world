# Kubernetes Namespace Module

This module creates Kubernetes resources required before Helm deployment:
- Namespace (optional)
- ServiceAccount with Workload Identity annotation
- ImagePullSecret for private container registry
- RBAC Role and RoleBinding for migration watcher

## Purpose

These resources must exist before Helm deployment because:
1. **ServiceAccount**: Needed for Workload Identity (GCP IAM binding references it)
2. **ImagePullSecret**: Needed to pull container images from private registry (ghcr.io)
3. **RBAC**: Init containers need permissions to query migration pod status

## Resources Created

- `kubernetes_namespace.app` - Kubernetes namespace (optional)
- `kubernetes_service_account_v1.app_with_image_pull_secret` - ServiceAccount with Workload Identity
- `kubernetes_secret.ghcr` - Docker registry credentials
- `kubernetes_role.migration_watcher` - RBAC role for pod/job queries
- `kubernetes_role_binding.migration_watcher` - RBAC role binding

## Usage

```hcl
module "k8s_namespace" {
  source = "../../modules/k8s-namespace"

  # Namespace
  namespace_name    = "baby-names-staging"
  create_namespace  = true  # Set to false if Helm creates it
  app_name          = "baby-names"

  # ServiceAccount and Workload Identity
  service_account_name       = "baby-names-staging"
  gcp_service_account_email  = "hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com"

  # ImagePullSecret for ghcr.io
  image_pull_secret_name = "ghcr-secret"
  registry_server        = "ghcr.io"
  registry_username      = "andrewesweet"
  registry_password      = var.github_token  # Sensitive variable
  registry_email         = "noreply@github.com"

  # Labels
  namespace_labels = {
    environment = "staging"
    team        = "platform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| namespace_name | Name of the Kubernetes namespace | string | n/a | yes |
| create_namespace | Whether to create the namespace | bool | true | no |
| namespace_labels | Additional labels for the namespace | map(string) | {} | no |
| namespace_annotations | Additional annotations for the namespace | map(string) | {} | no |
| app_name | Application name for labels | string | "baby-names" | no |
| service_account_name | Name of the Kubernetes ServiceAccount | string | n/a | yes |
| gcp_service_account_email | GCP service account email for Workload Identity | string | n/a | yes |
| image_pull_secret_name | Name of the image pull secret | string | "ghcr-secret" | no |
| registry_server | Container registry server | string | "ghcr.io" | no |
| registry_username | Container registry username | string | n/a | yes |
| registry_password | Container registry password/token | string | n/a | yes (sensitive) |
| registry_email | Container registry email | string | "noreply@github.com" | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace_name | Name of the Kubernetes namespace |
| service_account_name | Name of the Kubernetes ServiceAccount |
| image_pull_secret_name | Name of the image pull secret |
| role_name | Name of the RBAC role |
| role_binding_name | Name of the RBAC role binding |
| workload_identity_annotation | Workload Identity annotation on the ServiceAccount |

## Dependencies

- **GKE Cluster**: Must exist and be accessible
- **GCP Service Account**: Must exist with Workload Identity binding

## Permissions Required

The Terraform execution service account needs:
- `roles/container.admin` - To get GKE credentials and create Kubernetes resources

## Important Notes

### 1. Namespace Creation

You can either:
- **Option A**: Let Terraform create it (`create_namespace = true`)
- **Option B**: Let Helm create it (`create_namespace = false`, use `helm --create-namespace`)

The current Helm chart has `namespace.create: false` in values-staging.yaml, so set `create_namespace = true` in Terraform.

### 2. Workload Identity Annotation

The ServiceAccount annotation `iam.gke.io/gcp-service-account` enables Workload Identity:

```yaml
iam.gke.io/gcp-service-account: hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com
```

This must match the GCP service account created by the `gcp-service-account` module.

### 3. ImagePullSecret Security

**Best Practices:**
- Use a GitHub Personal Access Token (PAT) with **read:packages** scope only
- Mark the `registry_password` variable as sensitive
- Store in Terraform Cloud/Enterprise encrypted variables, not in version control
- Rotate tokens regularly

### 4. RBAC Permissions

The `migration-watcher` role allows init containers to:
- Get/list/watch pods (to check migration pod status)
- Get/list/watch jobs (to check migration job status)

Without this, init containers fail with:
```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:baby-names-staging:baby-names-staging"
cannot list resource "pods" in API group "" in the namespace "baby-names-staging"
```

### 5. ServiceAccount Patching

The module creates the ServiceAccount twice:
1. Initial creation via `kubernetes_service_account.app`
2. Patch with ImagePullSecret via `kubernetes_service_account_v1.app_with_image_pull_secret`

This ensures proper dependency ordering (secret must exist before being referenced).

## Troubleshooting

**ImagePullBackOff errors:**
1. Verify secret exists: `kubectl get secret ghcr-secret -n baby-names-staging`
2. Check SA has imagePullSecrets: `kubectl get sa baby-names-staging -n baby-names-staging -o yaml`
3. Verify GitHub PAT has read:packages scope
4. Test pull manually: `docker login ghcr.io -u <username> -p <token>`

**Workload Identity errors:**
1. Verify annotation: `kubectl get sa baby-names-staging -n baby-names-staging -o yaml`
2. Check GCP IAM binding exists (see gcp-service-account module)
3. Ensure Workload Identity is enabled on cluster

**RBAC errors:**
1. Verify role exists: `kubectl get role migration-watcher -n baby-names-staging`
2. Verify binding exists: `kubectl get rolebinding migration-watcher-binding -n baby-names-staging`
3. Check binding references correct SA: `kubectl get rolebinding migration-watcher-binding -n baby-names-staging -o yaml`
