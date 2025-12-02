# Troubleshooting Reference

This document provides troubleshooting guides for Claude Code.

## Podman on WSL2

### Docker commands fail with permission denied
**Solution**: Set `DOCKER_HOST` environment variable:
```bash
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
```

### Unqualified image names not found
**Solution**: Configure `/etc/containers/registries.conf.d/00-unqualified-search-registries.conf`:
```bash
sudo tee /etc/containers/registries.conf.d/00-unqualified-search-registries.conf > /dev/null <<EOF
unqualified-search-registries = ["docker.io"]
EOF
```

## Database Migrations

### PostgreSQL COPY command fails in containers
**Solution**: Use INSERT statements instead of COPY FROM for CSV data loading.

## GKE Deployment

### ImagePullBackOff: "dial tcp ... i/o timeout"
**Root Cause**: Private GKE cluster nodes cannot reach external registries without Cloud NAT.
**Solution**: Configure Cloud NAT:
```bash
gcloud compute routers create nat-router --network default --region europe-west1 --project <PROJECT_ID>
gcloud compute routers nats create nat-config \
  --router nat-router \
  --region europe-west1 \
  --nat-all-subnet-ip-ranges \
  --auto-allocate-nat-external-ips \
  --project <PROJECT_ID>
```

### ImagePullBackOff: "401 Unauthorized" or "403 Forbidden"
**Root Cause**: Cluster lacks credentials for private GitHub Container Registry.
**Solution**: Create imagePullSecret:
```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USERNAME> \
  --docker-password=<GITHUB_PAT> \
  --docker-email=noreply@github.com \
  -n <NAMESPACE>

kubectl patch serviceaccount <SERVICE_ACCOUNT_NAME> \
  -n <NAMESPACE> \
  -p '{"imagePullSecrets": [{"name": "ghcr-secret"}]}'
```

### ImagePullBackOff: "not found"
**Root Cause**: CI pushes `main` tag, CD uses SHA-based tags.
**Solution**: Use `main` tag in Helm:
```bash
helm upgrade --install baby-names . \
  --set backend.image.tag=main \
  --set frontend.image.tag=main \
  --set migration.image.tag=main
```

### Cloud SQL Proxy: "Permission 'iam.serviceAccounts.getAccessToken' denied"
**Root Cause**: K8s SA not bound to GCP SA via Workload Identity.
**Solution**:
```bash
gcloud iam service-accounts add-iam-policy-binding <GCP_SA_EMAIL> \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:<PROJECT_ID>.svc.id.goog[<NAMESPACE>/<K8S_SA_NAME>]" \
  --project <PROJECT_ID>
```

### Cloud SQL Proxy: "Cloud SQL Admin API has not been used"
**Root Cause**: API disabled.
**Solution**:
```bash
gcloud services enable sqladmin.googleapis.com --project=<PROJECT_ID>
```

### Database: "Cloud SQL IAM service account authentication failed"
**Root Cause**: IAM authentication not enabled on CloudSQL instance.
**Solution**:
```bash
gcloud sql instances patch <INSTANCE_NAME> \
  --database-flags=cloudsql.iam_authentication=on \
  --project=<PROJECT_ID>
```
**Note**: Instance will restart.

### Database: IAM auth fails (after flag enabled)
**Root Cause**: IAM database user doesn't exist or lacks PostgreSQL permissions.
**Solution**: Create IAM user and grant permissions:
```bash
gcloud sql users create "<GCP_SA_EMAIL>" \
  --instance=<INSTANCE_NAME> \
  --type=CLOUD_IAM_SERVICE_ACCOUNT \
  --project <PROJECT_ID>
```
Then grant PostgreSQL permissions using postgres user via Cloud SQL Proxy.

### Init containers stuck waiting for migration
**Root Cause**: Migration job with Cloud SQL Proxy sidecar never completes (sidecar doesn't exit).
**Solution**: Check migration container exit code instead of job completion, and create RBAC:
```bash
kubectl create role migration-watcher --verb=get,list,watch --resource=pods,jobs -n <NAMESPACE>
kubectl create rolebinding migration-watcher-binding \
  --role=migration-watcher \
  --serviceaccount=<NAMESPACE>:<SERVICE_ACCOUNT_NAME> \
  -n <NAMESPACE>
```
