# GCP Service Account Module

This module creates a GCP service account for application workloads and configures IAM bindings for:
- Cloud SQL access
- Workload Identity (Kubernetes pod authentication)

## Purpose

The service account enables Kubernetes pods to:
1. Authenticate to Cloud SQL using IAM (passwordless)
2. Use Workload Identity to impersonate the GCP service account

## Resources Created

- `google_service_account.app` - Application workload service account
- `google_project_iam_member.cloudsql_client` - Cloud SQL Client role
- `google_project_iam_member.cloudsql_instance_user` - Cloud SQL Instance User role (conditional)
- `google_service_account_iam_member.workload_identity_user` - Workload Identity binding

## Usage

```hcl
module "gcp_service_account" {
  source = "../../modules/gcp-service-account"

  project_id         = "extended-ascent-477308-m8"
  service_account_id = "hello-world-staging"
  display_name       = "Baby Names App - Staging"
  description        = "Service account for baby-names application in staging"

  # Workload Identity binding
  k8s_namespace             = "baby-names-staging"
  k8s_service_account_name  = "baby-names-staging"

  # Enable CloudSQL IAM authentication
  enable_cloudsql_instance_user_role = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | n/a | yes |
| service_account_id | Service account ID (the part before @) | string | n/a | yes |
| display_name | Display name for the service account | string | "" | no |
| description | Description of the service account | string | "Application workload service account for CloudSQL access" | no |
| k8s_namespace | Kubernetes namespace for Workload Identity binding | string | n/a | yes |
| k8s_service_account_name | Kubernetes ServiceAccount name for Workload Identity binding | string | n/a | yes |
| enable_cloudsql_instance_user_role | Enable Cloud SQL Instance User role | bool | true | no |

## Outputs

| Name | Description |
|------|-------------|
| service_account_email | Email address of the service account |
| service_account_name | Fully qualified name of the service account |
| service_account_id | Service account ID |
| workload_identity_member | Workload Identity member string for K8s SA annotation |
| cloudsql_iam_user | CloudSQL IAM database user name (email with .iam suffix) |

## Dependencies

- **Kubernetes namespace** and **ServiceAccount** must exist or be known beforehand
- **GKE cluster** with Workload Identity enabled

## Permissions Required

The Terraform execution service account needs:
- `roles/iam.serviceAccountAdmin` - To create service accounts
- `roles/resourcemanager.projectIamAdmin` - To set project-level IAM bindings
- `roles/iam.securityAdmin` - To set service account-level IAM bindings

## Workload Identity Flow

1. Kubernetes pod uses Kubernetes ServiceAccount (e.g., `baby-names-staging`)
2. Kubernetes SA is annotated with `iam.gke.io/gcp-service-account: <GCP_SA_EMAIL>`
3. This module creates IAM binding: `roles/iam.workloadIdentityUser`
4. Pod can now impersonate GCP service account
5. GCP service account has `roles/cloudsql.client` and `roles/cloudsql.instanceUser`
6. Pod can authenticate to Cloud SQL using IAM

## CloudSQL IAM Database User

After creating this service account, you must also:
1. Create the IAM database user in CloudSQL (see `cloudsql` module)
2. Grant PostgreSQL permissions (see `database-bootstrap` module)

The database user name will be: `{service_account_email}.iam`
