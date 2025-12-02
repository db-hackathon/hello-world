# GKE Deployment Reference

This document provides GKE deployment details for Claude Code.

## Target Infrastructure

| Component | Value |
|-----------|-------|
| GKE Cluster | `hellow-world-manual` in `europe-west1` |
| CloudSQL Instance | `hello-world-manual` in `europe-west1` |
| Namespace | `baby-names-staging` |
| Cluster Type | Private with Workload Identity enabled |

## Helm Deployment

```bash
cd examples/baby-names/helm/baby-names

# NOTE: Namespace and ServiceAccount are created by Terraform (not Helm)
helm upgrade --install baby-names . \
  --namespace baby-names-staging \
  --values values-staging.yaml \
  --set backend.image.tag=main-abc123 \
  --set frontend.image.tag=main-abc123 \
  --set migration.image.tag=main-abc123

# Verify deployment
kubectl get pods -n baby-names-staging
kubectl get ingress -n baby-names-staging
```

## Required Infrastructure Components

### Cloud NAT
Router `nat-router` with NAT config `nat-config` in `europe-west1` for private cluster egress.

### APIs
- Cloud SQL Admin API: `gcloud services enable sqladmin.googleapis.com`

### CloudSQL
- IAM Authentication Flag: `cloudsql.iam_authentication=on` (triggers restart)

### GCP Service Account
`hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com` with:
- `roles/cloudsql.client` (project-level)
- `roles/cloudsql.instanceUser` (project-level, conditional on resource tags)
- `roles/iam.workloadIdentityUser` (service account-level binding to K8s SA)

### IAM Database User
`hello-world-staging@extended-ascent-477308-m8.iam` (CloudSQL IAM user) with:
- ALL PRIVILEGES on `baby_names` database
- CREATE permission on public schema
- Default privileges configured for future objects

### Kubernetes Resources
- **ImagePullSecret**: `ghcr-secret` with GitHub PAT (read:packages scope)
- **RBAC**: Role `migration-watcher` granting get/list/watch on pods/jobs

## Workload Identity Provider

```
projects/785558430619/locations/global/workloadIdentityPools/github-2023/providers/github-2023
```

## Ingress

```
gke-df4e635bf6a042d9a06ccadd5f88beab6860-254825841253.europe-west1.gke.goog
```

## Production Deployment (Future)

- Manual approval via GitHub Environments
- Blue-green or canary deployment
- Gradual traffic shifting
- Automatic rollback on failure
