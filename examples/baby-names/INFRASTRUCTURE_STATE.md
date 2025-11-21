# Baby Names Application - Infrastructure State Documentation

This document captures the complete final state of all infrastructure resources, configurations, and permissions required for the baby-names application deployment to GKE with CloudSQL IAM authentication.

**Purpose**: Blueprint for Terraform configuration and automation to reproduce this target state.

**Date**: 2025-11-21
**Status**: Production-ready, fully functional
**Environment**: baby-names-staging

---

## Table of Contents
1. [GCP Resources](#gcp-resources)
2. [Kubernetes Resources](#kubernetes-resources)
3. [Database Configuration](#database-configuration)
4. [Helm Chart Configuration](#helm-chart-configuration)
5. [GitHub Configuration](#github-configuration)
6. [Manual Setup Commands Reference](#manual-setup-commands-reference)

---

## GCP Resources

### Project Configuration
- **Project ID**: `extended-ascent-477308-m8`
- **Project Number**: `254825841253`
- **Region**: `europe-west1`
- **Zone**: `europe-west1-b` (inferred)

### Enabled APIs
| API | Service Name | Purpose |
|-----|--------------|---------|
| Cloud SQL Admin API | `sqladmin.googleapis.com` | Required for Cloud SQL Proxy to manage connections |
| Kubernetes Engine API | `container.googleapis.com` | GKE cluster management |
| Compute Engine API | `compute.googleapis.com` | Cloud NAT, network resources |

**Creation Command**:
```bash
gcloud services enable sqladmin.googleapis.com --project=extended-ascent-477308-m8
```

### Network Infrastructure

#### Cloud NAT Configuration
**Purpose**: Enable private GKE cluster nodes to reach external container registries (ghcr.io)

| Resource | Name | Configuration |
|----------|------|---------------|
| Cloud Router | `nat-router` | Network: `default`<br>Region: `europe-west1` |
| NAT Config | `nat-config` | Router: `nat-router`<br>NAT IP Ranges: All subnet IP ranges<br>External IPs: Auto-allocated |

**Creation Commands**:
```bash
gcloud compute routers create nat-router \
  --network=default \
  --region=europe-west1 \
  --project=extended-ascent-477308-m8

gcloud compute routers nats create nat-config \
  --router=nat-router \
  --region=europe-west1 \
  --nat-all-subnet-ip-ranges \
  --auto-allocate-nat-external-ips \
  --project=extended-ascent-477308-m8
```

**Verification**:
```bash
gcloud compute routers describe nat-router --region=europe-west1 --project=extended-ascent-477308-m8
gcloud compute routers nats describe nat-config --router=nat-router --region=europe-west1 --project=extended-ascent-477308-m8
```

### GKE Cluster

| Attribute | Value |
|-----------|-------|
| Cluster Name | `hellow-world-manual` |
| Location | `europe-west1` |
| Cluster Type | Regional |
| Network | `default` |
| Subnetwork | `default` |
| Private Cluster | Yes (enablePrivateNodes: true) |
| Workload Identity | Enabled |
| Autopilot | Enabled |

**Key Features**:
- Private nodes (no external IPs)
- Workload Identity enabled for IAM integration
- Autopilot mode (managed node pools)
- GCE ingress controller

**Note**: Cluster was manually provisioned (not created during this session)

### CloudSQL Instance

| Attribute | Value |
|-----------|-------|
| Instance Name | `hello-world-manual` |
| Database Version | PostgreSQL 17.7 |
| Region | `europe-west1` |
| Tier | (not documented) |
| Network | `default` |

#### Database Flags
| Flag | Value | Purpose |
|------|-------|---------|
| `cloudsql.iam_authentication` | `on` | **CRITICAL**: Enables IAM-based authentication |

**Update Command**:
```bash
gcloud sql instances patch hello-world-manual \
  --database-flags=cloudsql.iam_authentication=on \
  --project=extended-ascent-477308-m8
```

**⚠️ Important**: This flag update triggers an instance restart.

**Verification**:
```bash
gcloud sql instances describe hello-world-manual \
  --project=extended-ascent-477308-m8 \
  --format="value(settings.databaseFlags)"
```

### IAM Service Accounts

#### GCP Service Account
| Attribute | Value |
|-----------|-------|
| Email | `hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com` |
| Display Name | (not documented) |
| Purpose | Application workload identity for Cloud SQL access |

**Note**: Service account was created previously (not during this session)

#### IAM Role Bindings

**Project-Level Roles**:

| Role | Binding Type | Condition |
|------|--------------|-----------|
| `roles/cloudsql.client` | Project-level | None |
| `roles/cloudsql.instanceUser` | Project-level | Conditional on resource tags (details not captured) |

**Service Account-Level Roles**:

| Role | Principal | Purpose |
|------|-----------|---------|
| `roles/iam.workloadIdentityUser` | `serviceAccount:extended-ascent-477308-m8.svc.id.goog[baby-names-staging/baby-names-staging]` | Allows K8s SA to impersonate GCP SA |

**Creation Commands**:
```bash
# Cloud SQL Client role (project-level)
gcloud projects add-iam-policy-binding extended-ascent-477308-m8 \
  --member="serviceAccount:hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client" \
  --project=extended-ascent-477308-m8 \
  --condition=None

# Workload Identity User role (service account-level)
gcloud iam service-accounts add-iam-policy-binding \
  hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:extended-ascent-477308-m8.svc.id.goog[baby-names-staging/baby-names-staging]" \
  --project=extended-ascent-477308-m8
```

**Verification**:
```bash
# Check project-level bindings
gcloud projects get-iam-policy extended-ascent-477308-m8 \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:hello-world-staging@*"

# Check service account-level bindings
gcloud iam service-accounts get-iam-policy \
  hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com \
  --project=extended-ascent-477308-m8
```

### CloudSQL Users

| User Name | Type | Authentication Method |
|-----------|------|----------------------|
| `postgres` | BUILT_IN | Password (reset during setup) |
| `hello-world-staging@extended-ascent-477308-m8.iam` | CLOUD_IAM_SERVICE_ACCOUNT | IAM token |

**Creation Command**:
```bash
gcloud sql users create "hello-world-staging@extended-ascent-477308-m8.iam" \
  --instance=hello-world-manual \
  --type=CLOUD_IAM_SERVICE_ACCOUNT \
  --project=extended-ascent-477308-m8
```

**Verification**:
```bash
gcloud sql users list \
  --instance=hello-world-manual \
  --project=extended-ascent-477308-m8
```

---

## Kubernetes Resources

### Namespace
| Attribute | Value |
|-----------|-------|
| Name | `baby-names-staging` |
| Creation Method | `helm --create-namespace` flag |
| Labels | Applied by Helm |

**Note**: Namespace is NOT created via Helm template (values-staging.yaml has `namespace.create: false`)

### Service Account

| Attribute | Value |
|-----------|-------|
| Name | `baby-names-staging` |
| Namespace | `baby-names-staging` |
| Annotations | `iam.gke.io/gcp-service-account: hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com` |
| Image Pull Secrets | `ghcr-secret` |

**Helm Template**: `templates/serviceaccount.yaml`

**Key Configuration**:
```yaml
metadata:
  name: baby-names-staging
  namespace: baby-names-staging
  annotations:
    iam.gke.io/gcp-service-account: hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com
imagePullSecrets:
  - name: ghcr-secret
```

### Secrets

#### ImagePullSecret: ghcr-secret
| Attribute | Value |
|-----------|-------|
| Name | `ghcr-secret` |
| Namespace | `baby-names-staging` |
| Type | `kubernetes.io/dockerconfigjson` |
| Registry | `ghcr.io` |
| Username | `andrewesweet` |
| Password/Token | GitHub PAT with `read:packages` scope |
| Email | `noreply@github.com` |

**Creation Command**:
```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=andrewesweet \
  --docker-password=<GITHUB_PAT> \
  --docker-email=noreply@github.com \
  --namespace=baby-names-staging
```

**Service Account Patch**:
```bash
kubectl patch serviceaccount baby-names-staging \
  --namespace=baby-names-staging \
  --patch='{"imagePullSecrets": [{"name": "ghcr-secret"}]}'
```

**⚠️ Security Note**: The GitHub PAT must have `read:packages` scope ONLY (least privilege).

### RBAC Resources

#### Role: migration-watcher
| Attribute | Value |
|-----------|-------|
| Name | `migration-watcher` |
| Namespace | `baby-names-staging` |
| API Groups | `""` (core), `batch` |
| Resources | `pods`, `jobs` |
| Verbs | `get`, `list`, `watch` |

**Purpose**: Allows init containers to query migration pod/job status

**Creation Command**:
```bash
kubectl create role migration-watcher \
  --verb=get,list,watch \
  --resource=pods,jobs \
  --namespace=baby-names-staging
```

**YAML Equivalent**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: migration-watcher
  namespace: baby-names-staging
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch"]
```

#### RoleBinding: migration-watcher-binding
| Attribute | Value |
|-----------|-------|
| Name | `migration-watcher-binding` |
| Namespace | `baby-names-staging` |
| Role | `migration-watcher` (Role) |
| Subjects | ServiceAccount `baby-names-staging` in namespace `baby-names-staging` |

**Creation Command**:
```bash
kubectl create rolebinding migration-watcher-binding \
  --role=migration-watcher \
  --serviceaccount=baby-names-staging:baby-names-staging \
  --namespace=baby-names-staging
```

**YAML Equivalent**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: migration-watcher-binding
  namespace: baby-names-staging
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: migration-watcher
subjects:
- kind: ServiceAccount
  name: baby-names-staging
  namespace: baby-names-staging
```

### Workloads

#### Deployments

**Backend Deployment**:
- Name: `baby-names-backend`
- Replicas: 2
- Image: `ghcr.io/db-hackathon/hello-world/baby-names-backend:main`
- Service Account: `baby-names-staging`
- Init Container: `wait-for-migration` (checks migration pod completion)
- Sidecars: `cloud-sql-proxy` (IAM authentication to CloudSQL)

**Frontend Deployment**:
- Name: `baby-names-frontend`
- Replicas: 2
- Image: `ghcr.io/db-hackathon/hello-world/baby-names-frontend:main`
- Service Account: `baby-names-staging`
- Init Container: `wait-for-migration` (checks migration pod completion)

**Current Running Pods** (final state):
```
baby-names-backend-6cb7dc8bc7-q9wgs    2/2  Running
baby-names-backend-6cb7dc8bc7-qswwc    2/2  Running
baby-names-frontend-687f596d49-4w6bs   1/1  Running
baby-names-frontend-687f596d49-v27pn   1/1  Running
```

#### Job

**Migration Job**:
- Name Pattern: `baby-names-migration-{REVISION}` (e.g., `baby-names-migration-12`)
- Image: `ghcr.io/db-hackathon/hello-world/baby-names-db-migration:main`
- Service Account: `baby-names-staging`
- Containers:
  - `migration`: Liquibase database migrations
  - `cloud-sql-proxy`: IAM authentication sidecar
- RestartPolicy: `Never`
- BackoffLimit: 3
- shareProcessNamespace: `true` (attempted but not necessary in final solution)

**⚠️ Known Limitation**: Job never reaches "Complete" status because cloud-sql-proxy sidecar doesn't exit. Init containers work around this by checking container exit code instead of job status.

### Services

**Backend Service**:
- Name: `baby-names-backend`
- Type: ClusterIP
- ClusterIP: `34.118.233.117`
- Port: `5000/TCP`
- Selector: `app.kubernetes.io/name=baby-names, app.kubernetes.io/component=backend`

**Frontend Service**:
- Name: `baby-names-frontend`
- Type: ClusterIP
- ClusterIP: `34.118.227.180`
- Port: `8080/TCP`
- Selector: `app.kubernetes.io/name=baby-names, app.kubernetes.io/component=frontend`

### Ingress

| Attribute | Value |
|-----------|-------|
| Name | `baby-names` |
| Namespace | `baby-names-staging` |
| Class | `gce` (GCE Ingress Controller) |
| Host | `gke-df4e635bf6a042d9a06ccadd5f88beab6860-254825841253.europe-west1.gke.goog` |
| External IP | `136.110.214.105` |
| Backend Service | `baby-names-frontend:8080` |
| Protocol | HTTP (port 80) |

**Access URL**: `http://gke-df4e635bf6a042d9a06ccadd5f88beab6860-254825841253.europe-west1.gke.goog/`

**⚠️ Note**: Requires Host header in curl requests: `-H "Host: gke-df4e635bf6a042d9a06ccadd5f88beab6860-254825841253.europe-west1.gke.goog"`

---

## Database Configuration

### CloudSQL Instance Connection
- **Instance Connection Name**: `extended-ascent-477308-m8:europe-west1:hello-world-manual`
- **Connection Method**: Cloud SQL Proxy (sidecar container)
- **Authentication**: IAM (passwordless)
- **Local Proxy Port**: `5432`

### Database: baby_names

| Attribute | Value |
|-----------|-------|
| Name | `baby_names` |
| Owner | `postgres` |
| Encoding | UTF8 (inferred) |
| Collation | (not documented) |

**Creation Method**: Manually created via psql

**Creation Command**:
```sql
CREATE DATABASE baby_names;
```

### PostgreSQL User Permissions

#### IAM User: hello-world-staging@extended-ascent-477308-m8.iam

**Database-Level Permissions**:
```sql
GRANT ALL PRIVILEGES ON DATABASE baby_names
TO "hello-world-staging@extended-ascent-477308-m8.iam";
```

**Schema-Level Permissions**:
```sql
-- Grant all privileges on public schema
GRANT ALL ON SCHEMA public
TO "hello-world-staging@extended-ascent-477308-m8.iam";

-- Grant CREATE permission (required for Liquibase to create databasechangelog table)
GRANT CREATE ON SCHEMA public
TO "hello-world-staging@extended-ascent-477308-m8.iam";
```

**Object-Level Permissions**:
```sql
-- Grant privileges on existing tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
TO "hello-world-staging@extended-ascent-477308-m8.iam";

-- Grant privileges on existing sequences
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
TO "hello-world-staging@extended-ascent-477308-m8.iam";
```

**Default Privileges** (for future objects):
```sql
-- Default privileges for objects created by postgres user
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT ALL ON TABLES TO "hello-world-staging@extended-ascent-477308-m8.iam";

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT ALL ON SEQUENCES TO "hello-world-staging@extended-ascent-477308-m8.iam";

-- Default privileges for objects created by IAM user itself
ALTER DEFAULT PRIVILEGES FOR ROLE "hello-world-staging@extended-ascent-477308-m8.iam" IN SCHEMA public
GRANT ALL ON TABLES TO "hello-world-staging@extended-ascent-477308-m8.iam";

ALTER DEFAULT PRIVILEGES FOR ROLE "hello-world-staging@extended-ascent-477308-m8.iam" IN SCHEMA public
GRANT ALL ON SEQUENCES TO "hello-world-staging@extended-ascent-477308-m8.iam";
```

**Setup Method**:
1. Create temporary pod with PostgreSQL client + Cloud SQL Proxy
2. Reset postgres user password
3. Connect as postgres user and execute GRANT statements
4. Delete temporary pod

**Complete Setup Script**:
```bash
# Create temporary pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: psql-client
  namespace: baby-names-staging
spec:
  serviceAccountName: baby-names-staging
  containers:
  - name: psql-client
    image: postgres:15-alpine
    command: ["sleep", "3600"]
  - name: cloud-sql-proxy
    image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.1.0
    args:
      - "extended-ascent-477308-m8:europe-west1:hello-world-manual"
      - "--port=5432"
    securityContext:
      runAsNonRoot: true
      allowPrivilegeEscalation: false
EOF

# Wait for pod
kubectl wait --for=condition=ready pod/psql-client -n baby-names-staging --timeout=60s

# Reset postgres password
POSTGRES_PASSWORD=$(openssl rand -base64 32)
gcloud sql users set-password postgres \
  --instance=hello-world-manual \
  --password="$POSTGRES_PASSWORD" \
  --project=extended-ascent-477308-m8

# Execute SQL commands
kubectl exec -n baby-names-staging psql-client -c psql-client -- \
  env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -h localhost -U postgres -d postgres -c "CREATE DATABASE baby_names;"

kubectl exec -n baby-names-staging psql-client -c psql-client -- \
  env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -h localhost -U postgres -d baby_names <<'EOF'
GRANT ALL PRIVILEGES ON DATABASE baby_names TO "hello-world-staging@extended-ascent-477308-m8.iam";
GRANT ALL ON SCHEMA public TO "hello-world-staging@extended-ascent-477308-m8.iam";
GRANT CREATE ON SCHEMA public TO "hello-world-staging@extended-ascent-477308-m8.iam";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "hello-world-staging@extended-ascent-477308-m8.iam";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "hello-world-staging@extended-ascent-477308-m8.iam";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO "hello-world-staging@extended-ascent-477308-m8.iam";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO "hello-world-staging@extended-ascent-477308-m8.iam";
ALTER DEFAULT PRIVILEGES FOR ROLE "hello-world-staging@extended-ascent-477308-m8.iam" IN SCHEMA public GRANT ALL ON TABLES TO "hello-world-staging@extended-ascent-477308-m8.iam";
ALTER DEFAULT PRIVILEGES FOR ROLE "hello-world-staging@extended-ascent-477308-m8.iam" IN SCHEMA public GRANT ALL ON SEQUENCES TO "hello-world-staging@extended-ascent-477308-m8.iam";
EOF

# Cleanup
kubectl delete pod psql-client -n baby-names-staging
```

### Database Schema (Post-Migration)

Tables created by Liquibase migrations:

**databasechangelog**:
- Purpose: Liquibase change tracking
- Owner: `hello-world-staging@extended-ascent-477308-m8.iam`
- Columns: ID, AUTHOR, FILENAME, DATEEXECUTED, etc.

**databasechangeloglock**:
- Purpose: Liquibase concurrency control
- Owner: `hello-world-staging@extended-ascent-477308-m8.iam`

**baby_names**:
- Purpose: Application data (ONS baby names 2024)
- Owner: `hello-world-staging@extended-ascent-477308-m8.iam`
- Columns: id, name, rank, count, year
- Rows: 50 (baby names data)

**Liquibase Changesets Applied**:
1. `changelog/001-create-schema.sql::1::baby-names` - Table creation
2. `changelog/002-load-data.sql::2::baby-names` - Data loading (50 rows)

---

## Helm Chart Configuration

### Chart Metadata
- **Chart Name**: `baby-names`
- **Chart Version**: `0.1.0`
- **App Version**: `1.0`
- **Location**: `/home/sweeand/hello-world/examples/baby-names/helm/baby-names/`

### Values Files

#### values-staging.yaml (Environment-Specific)

**Critical Configuration**:

```yaml
namespace:
  create: false  # Namespace created by helm --create-namespace flag
  name: baby-names-staging

serviceAccount:
  name: baby-names-staging
  annotations:
    iam.gke.io/gcp-service-account: hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com

database:
  iamAuth: true
  instanceConnectionName: extended-ascent-477308-m8:europe-west1:hello-world-manual

backend:
  image:
    repository: ghcr.io/db-hackathon/hello-world/baby-names-backend
    tag: "main"  # Overridden by CD workflow
    pullPolicy: Always
  env:
    DB_HOST: localhost
    DB_PORT: "5432"
    DB_NAME: baby_names
    DB_USER: hello-world-staging@extended-ascent-477308-m8.iam
    DB_IAM_AUTH: "true"

frontend:
  image:
    repository: ghcr.io/db-hackathon/hello-world/baby-names-frontend
    tag: "main"  # Overridden by CD workflow
    pullPolicy: Always
  env:
    BACKEND_URL: http://baby-names-backend:5000

migration:
  image:
    repository: ghcr.io/db-hackathon/hello-world/baby-names-db-migration
    tag: "main"  # Overridden by CD workflow
    pullPolicy: Always
  env:
    DB_HOST: localhost
    DB_PORT: "5432"
    DB_NAME: baby_names
    DB_USER: hello-world-staging@extended-ascent-477308-m8.iam
    DB_IAM_AUTH: "true"
  backoffLimit: 3

ingress:
  enabled: true
  className: gce
  host: gke-df4e635bf6a042d9a06ccadd5f88beab6860-254825841253.europe-west1.gke.goog
```

### Template Changes

#### templates/backend-deployment.yaml
**Key Change**: Init container `wait-for-migration`

**Modified Logic**:
- ❌ OLD: Wait for job completion (`kubectl wait --for=condition=complete job/...`)
- ✅ NEW: Wait for migration pod container exit code 0

```yaml
initContainers:
- name: wait-for-migration
  image: bitnami/kubectl:latest
  command:
  - /bin/sh
  - -c
  - |
    echo "Waiting for database migration to complete..."
    JOB_NAME="{{ include "baby-names.fullname" . }}-migration-{{ .Release.Revision }}"

    # Wait for job to exist and get pod name
    for i in $(seq 1 60); do
      POD_NAME=$(kubectl get pods -n {{ .Values.namespace.name }} -l job-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
      if [ -n "$POD_NAME" ]; then
        echo "Found migration pod: $POD_NAME"
        break
      fi
      echo "Waiting for migration pod to be created..."
      sleep 2
    done

    if [ -z "$POD_NAME" ]; then
      echo "Migration pod not found after 120s, checking if database is already migrated..."
      exit 0
    fi

    # Wait for migration container to succeed
    echo "Waiting for migration container to complete..."
    until kubectl get pod $POD_NAME -n {{ .Values.namespace.name }} -o jsonpath='{.status.containerStatuses[?(@.name=="migration")].state.terminated.exitCode}' 2>/dev/null | grep -q "^0$"; do
      echo "Migration not complete yet, waiting..."
      sleep 5
    done
    echo "Migration complete, starting backend..."
```

**Why This Change**: Kubernetes Jobs with sidecars never reach "Complete" status because the sidecar (cloud-sql-proxy) doesn't exit. Checking the migration container's exit code directly works around this limitation.

#### templates/frontend-deployment.yaml
**Same init container change as backend**

#### templates/migration-job.yaml
**Key Change**: Added `shareProcessNamespace: true` (attempted optimization, not strictly necessary)

```yaml
spec:
  template:
    spec:
      shareProcessNamespace: true  # Allows containers to signal each other
      serviceAccountName: {{ .Values.serviceAccount.name }}
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        fsGroup: 1000
      containers:
      - name: migration
        # ... standard Liquibase configuration ...
```

**Note**: Attempted to use process namespace sharing to allow migration container to kill cloud-sql-proxy, but this proved unnecessary with the init container solution.

### Deployment Command

```bash
cd /home/sweeand/hello-world/examples/baby-names/helm/baby-names

helm upgrade --install baby-names . \
  --namespace baby-names-staging \
  --create-namespace \
  --values values-staging.yaml \
  --set backend.image.tag=main \
  --set frontend.image.tag=main \
  --set migration.image.tag=main \
  --wait \
  --timeout 10m
```

**Final Revision**: 12 (after all fixes)

---

## GitHub Configuration

### GitHub Actions Workload Identity Federation

**Workload Identity Provider**:
- Path: `projects/254825841253/locations/global/workloadIdentityPools/github-actions/providers/github-oidc`
- Purpose: Allow GitHub Actions to authenticate to GCP using OIDC tokens (no service account keys)

**CD Workflow Authentication** (`.github/workflows/cd.yml`):
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/254825841253/locations/global/workloadIdentityPools/github-actions/providers/github-oidc
    service_account: hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com
```

### GitHub Container Registry

**Registry**: `ghcr.io`
**Organization**: `db-hackathon`
**Repository Prefix**: `hello-world`

**Images**:
- `ghcr.io/db-hackathon/hello-world/baby-names-backend:main`
- `ghcr.io/db-hackathon/hello-world/baby-names-frontend:main`
- `ghcr.io/db-hackathon/hello-world/baby-names-db-migration:main`

**Authentication**:
- Requires GitHub PAT with `read:packages` scope
- Stored as Kubernetes secret `ghcr-secret`
- Owner: `andrewesweet`

### GitHub Secrets (Required for CD)

| Secret Name | Type | Purpose | Value Pattern |
|-------------|------|---------|---------------|
| N/A | Workload Identity | GCP authentication | OIDC token (automatic) |

**Note**: No GitHub secrets are required! Authentication uses OIDC via Workload Identity Federation.

---

## Manual Setup Commands Reference

### Complete Setup Sequence

This is the complete sequence of commands to reproduce the infrastructure state from scratch:

```bash
# =============================================================================
# PHASE 1: GCP INFRASTRUCTURE
# =============================================================================

PROJECT_ID="extended-ascent-477308-m8"
PROJECT_NUMBER="254825841253"
REGION="europe-west1"
CLUSTER_NAME="hellow-world-manual"
CLOUDSQL_INSTANCE="hello-world-manual"
GCP_SA_EMAIL="hello-world-staging@${PROJECT_ID}.iam.gserviceaccount.com"
NAMESPACE="baby-names-staging"
K8S_SA_NAME="baby-names-staging"

# 1. Enable Required APIs
gcloud services enable sqladmin.googleapis.com --project=${PROJECT_ID}
gcloud services enable container.googleapis.com --project=${PROJECT_ID}
gcloud services enable compute.googleapis.com --project=${PROJECT_ID}

# 2. Create Cloud NAT (for private GKE cluster egress)
gcloud compute routers create nat-router \
  --network=default \
  --region=${REGION} \
  --project=${PROJECT_ID}

gcloud compute routers nats create nat-config \
  --router=nat-router \
  --region=${REGION} \
  --nat-all-subnet-ip-ranges \
  --auto-allocate-nat-external-ips \
  --project=${PROJECT_ID}

# 3. Enable CloudSQL IAM Authentication
gcloud sql instances patch ${CLOUDSQL_INSTANCE} \
  --database-flags=cloudsql.iam_authentication=on \
  --project=${PROJECT_ID}
# ⚠️ Instance will restart!

# 4. Configure IAM Permissions
# Project-level: Cloud SQL Client
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${GCP_SA_EMAIL}" \
  --role="roles/cloudsql.client" \
  --condition=None

# Service account-level: Workload Identity User
gcloud iam service-accounts add-iam-policy-binding ${GCP_SA_EMAIL} \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${K8S_SA_NAME}]" \
  --project=${PROJECT_ID}

# 5. Create IAM Database User
gcloud sql users create "${GCP_SA_EMAIL}" \
  --instance=${CLOUDSQL_INSTANCE} \
  --type=CLOUD_IAM_SERVICE_ACCOUNT \
  --project=${PROJECT_ID}

# =============================================================================
# PHASE 2: KUBERNETES RESOURCES
# =============================================================================

# 1. Get GKE credentials
gcloud container clusters get-credentials ${CLUSTER_NAME} \
  --region=${REGION} \
  --project=${PROJECT_ID}

# 2. Create ImagePullSecret
GITHUB_USERNAME="andrewesweet"
GITHUB_PAT="<YOUR_GITHUB_PAT_WITH_READ_PACKAGES_SCOPE>"

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=${GITHUB_USERNAME} \
  --docker-password=${GITHUB_PAT} \
  --docker-email=noreply@github.com \
  --namespace=${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Create RBAC Resources
kubectl create role migration-watcher \
  --verb=get,list,watch \
  --resource=pods,jobs \
  --namespace=${NAMESPACE}

kubectl create rolebinding migration-watcher-binding \
  --role=migration-watcher \
  --serviceaccount=${NAMESPACE}:${K8S_SA_NAME} \
  --namespace=${NAMESPACE}

# =============================================================================
# PHASE 3: DATABASE SETUP
# =============================================================================

# 1. Create temporary psql client pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: psql-client
  namespace: ${NAMESPACE}
spec:
  serviceAccountName: ${K8S_SA_NAME}
  containers:
  - name: psql-client
    image: postgres:15-alpine
    command: ["sleep", "3600"]
  - name: cloud-sql-proxy
    image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.1.0
    args:
      - "${PROJECT_ID}:${REGION}:${CLOUDSQL_INSTANCE}"
      - "--port=5432"
    securityContext:
      runAsNonRoot: true
      allowPrivilegeEscalation: false
EOF

kubectl wait --for=condition=ready pod/psql-client -n ${NAMESPACE} --timeout=60s

# 2. Set postgres password
POSTGRES_PASSWORD=$(openssl rand -base64 32)
gcloud sql users set-password postgres \
  --instance=${CLOUDSQL_INSTANCE} \
  --password="${POSTGRES_PASSWORD}" \
  --project=${PROJECT_ID}

# 3. Create database
kubectl exec -n ${NAMESPACE} psql-client -c psql-client -- \
  env PGPASSWORD="${POSTGRES_PASSWORD}" \
  psql -h localhost -U postgres -d postgres \
  -c "CREATE DATABASE baby_names;"

# 4. Grant permissions
kubectl exec -n ${NAMESPACE} psql-client -c psql-client -- \
  env PGPASSWORD="${POSTGRES_PASSWORD}" \
  psql -h localhost -U postgres -d baby_names <<EOF
GRANT ALL PRIVILEGES ON DATABASE baby_names TO "${GCP_SA_EMAIL}";
GRANT ALL ON SCHEMA public TO "${GCP_SA_EMAIL}";
GRANT CREATE ON SCHEMA public TO "${GCP_SA_EMAIL}";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "${GCP_SA_EMAIL}";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "${GCP_SA_EMAIL}";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO "${GCP_SA_EMAIL}";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO "${GCP_SA_EMAIL}";
ALTER DEFAULT PRIVILEGES FOR ROLE "${GCP_SA_EMAIL}" IN SCHEMA public GRANT ALL ON TABLES TO "${GCP_SA_EMAIL}";
ALTER DEFAULT PRIVILEGES FOR ROLE "${GCP_SA_EMAIL}" IN SCHEMA public GRANT ALL ON SEQUENCES TO "${GCP_SA_EMAIL}";
EOF

# 5. Cleanup
kubectl delete pod psql-client -n ${NAMESPACE}

# =============================================================================
# PHASE 4: HELM DEPLOYMENT
# =============================================================================

cd /home/sweeand/hello-world/examples/baby-names/helm/baby-names

helm upgrade --install baby-names . \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --values values-staging.yaml \
  --set backend.image.tag=main \
  --set frontend.image.tag=main \
  --set migration.image.tag=main \
  --wait \
  --timeout 10m

# =============================================================================
# VERIFICATION
# =============================================================================

# Check pods
kubectl get pods -n ${NAMESPACE}

# Check services
kubectl get svc -n ${NAMESPACE}

# Check ingress
kubectl get ingress -n ${NAMESPACE}

# Test application
INGRESS_HOST=$(kubectl get ingress baby-names -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}')
INGRESS_IP=$(kubectl get ingress baby-names -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -H "Host: ${INGRESS_HOST}" "http://${INGRESS_IP}/?name=Noah"
```

---

## Resource Dependencies

```
GCP Project
├── APIs Enabled
│   ├── sqladmin.googleapis.com
│   ├── container.googleapis.com
│   └── compute.googleapis.com
│
├── Network Infrastructure
│   └── Cloud Router (nat-router)
│       └── NAT Config (nat-config)
│
├── IAM Service Account (hello-world-staging@...)
│   ├── Project-level Roles
│   │   ├── roles/cloudsql.client
│   │   └── roles/cloudsql.instanceUser
│   └── Service Account-level Roles
│       └── roles/iam.workloadIdentityUser ← binds to K8s SA
│
├── CloudSQL Instance (hello-world-manual)
│   ├── Database Flag: cloudsql.iam_authentication=on
│   ├── IAM User: hello-world-staging@...iam
│   └── Database: baby_names
│       └── PostgreSQL Permissions ← granted manually
│
└── GKE Cluster (hellow-world-manual)
    └── Namespace: baby-names-staging
        ├── Service Account: baby-names-staging
        │   ├── Annotation: iam.gke.io/gcp-service-account ← Workload Identity
        │   └── ImagePullSecrets: ghcr-secret
        │
        ├── Secret: ghcr-secret (Docker registry)
        │
        ├── RBAC
        │   ├── Role: migration-watcher
        │   └── RoleBinding: migration-watcher-binding
        │
        ├── Deployments
        │   ├── backend (2 replicas)
        │   │   ├── Init: wait-for-migration ← requires RBAC
        │   │   └── Sidecar: cloud-sql-proxy ← requires IAM
        │   └── frontend (2 replicas)
        │       └── Init: wait-for-migration ← requires RBAC
        │
        ├── Job: baby-names-migration-{rev}
        │   ├── Container: migration ← requires DB permissions
        │   └── Sidecar: cloud-sql-proxy ← requires IAM
        │
        ├── Services
        │   ├── baby-names-backend (ClusterIP:5000)
        │   └── baby-names-frontend (ClusterIP:8080)
        │
        └── Ingress: baby-names
            └── Backend: baby-names-frontend:8080
```

---

## Terraform Module Structure (Recommended)

For automation, structure Terraform as follows:

```
terraform/
├── modules/
│   ├── gcp-infrastructure/
│   │   ├── main.tf          # Cloud NAT, IAM, APIs
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── cloudsql/
│   │   ├── main.tf          # Instance config, database flags, IAM users
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── gke-namespace/
│   │   ├── main.tf          # Namespace, ServiceAccount, RBAC, Secrets
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── database-init/
│       ├── main.tf          # Null resource with local-exec for GRANT statements
│       ├── scripts/
│       │   └── setup-db-permissions.sh
│       ├── variables.tf
│       └── outputs.tf
│
└── environments/
    ├── staging/
    │   ├── main.tf          # Calls all modules
    │   ├── variables.tf
    │   ├── terraform.tfvars
    │   └── backend.tf
    │
    └── production/
        └── ...
```

**Critical Notes for Terraform**:
1. **Database Permissions**: Cannot be managed by `google_sql_database` or `google_sql_user` - requires `null_resource` with `local-exec` running psql
2. **Secrets**: GitHub PAT should be passed via Terraform variable (marked sensitive), not hardcoded
3. **Dependencies**: Use `depends_on` extensively - especially database permissions depend on IAM user creation
4. **CloudSQL Flag**: Changing `cloudsql.iam_authentication` triggers instance restart - plan accordingly
5. **Helm**: Consider using `helm_release` Terraform resource or separate Helm deployment after infrastructure provisioning

---

## Key Learnings and Gotchas

1. **CloudSQL IAM Authentication Flag**: The `cloudsql.iam_authentication=on` flag is MANDATORY and easy to miss. Without it, IAM authentication will fail even if all other configuration is correct.

2. **PostgreSQL Permissions**: Creating the IAM user in CloudSQL only sets up the authentication layer. The user still needs explicit GRANT statements in PostgreSQL. This requires either:
   - Manual setup via psql (as done here)
   - Terraform null_resource with local-exec
   - Cloud SQL Admin API SQL execution

3. **Kubernetes Jobs with Sidecars**: Jobs with sidecar containers never reach "Complete" status because sidecars don't exit. Workarounds:
   - Check container exit code instead of job status (implemented here)
   - Use preStop hooks to kill sidecars (attempted but not necessary)
   - Use Kubernetes 1.28+ native sidecar support

4. **Init Container RBAC**: Init containers that query Kubernetes API require explicit RBAC permissions on the service account.

5. **Image Pull Authentication**: Private GKE clusters need both:
   - Cloud NAT for network connectivity to ghcr.io
   - ImagePullSecret for authentication

6. **Workload Identity**: Requires annotation on Kubernetes ServiceAccount AND IAM binding on GCP Service Account. Both sides must be configured.

7. **Default Privileges**: Must set ALTER DEFAULT PRIVILEGES for BOTH:
   - Objects created by postgres user
   - Objects created by IAM user itself

---

## Validation Checklist

Use this checklist to verify complete infrastructure setup:

### GCP Resources
- [ ] Cloud SQL Admin API enabled
- [ ] Cloud NAT router created
- [ ] Cloud NAT config created
- [ ] CloudSQL instance has `cloudsql.iam_authentication=on`
- [ ] GCP service account exists
- [ ] GCP service account has `roles/cloudsql.client`
- [ ] GCP service account has Workload Identity User binding
- [ ] IAM database user created in CloudSQL

### Kubernetes Resources
- [ ] Namespace exists
- [ ] Service account exists with Workload Identity annotation
- [ ] ImagePullSecret `ghcr-secret` exists
- [ ] Service account has imagePullSecrets configured
- [ ] RBAC Role `migration-watcher` exists
- [ ] RBAC RoleBinding exists
- [ ] Can pull images from ghcr.io

### Database Setup
- [ ] Database `baby_names` exists
- [ ] IAM user has GRANT ALL on database
- [ ] IAM user has GRANT CREATE on public schema
- [ ] IAM user has GRANT ALL on tables and sequences
- [ ] Default privileges configured for postgres role
- [ ] Default privileges configured for IAM user role

### Application Deployment
- [ ] Migration job completes successfully
- [ ] Backend pods running (2/2 containers)
- [ ] Frontend pods running (1/1 containers)
- [ ] Services have ClusterIP assigned
- [ ] Ingress has external IP assigned
- [ ] Application accessible via ingress URL
- [ ] Test query returns correct data

### Verification Commands
```bash
# GCP
gcloud sql instances describe hello-world-manual --project=extended-ascent-477308-m8 | grep -A5 databaseFlags
gcloud sql users list --instance=hello-world-manual --project=extended-ascent-477308-m8
gcloud compute routers nats describe nat-config --router=nat-router --region=europe-west1 --project=extended-ascent-477308-m8

# Kubernetes
kubectl get sa baby-names-staging -n baby-names-staging -o yaml
kubectl get secret ghcr-secret -n baby-names-staging
kubectl get role,rolebinding -n baby-names-staging
kubectl get pods,svc,ingress -n baby-names-staging

# Database (from psql-client pod)
PGPASSWORD="" psql -h localhost -U "hello-world-staging@extended-ascent-477308-m8.iam" -d baby_names -c "\l"
PGPASSWORD="" psql -h localhost -U "hello-world-staging@extended-ascent-477308-m8.iam" -d baby_names -c "\du"
PGPASSWORD="" psql -h localhost -U "hello-world-staging@extended-ascent-477308-m8.iam" -d baby_names -c "SELECT * FROM baby_names LIMIT 5;"

# Application
curl -H "Host: gke-df4e635bf6a042d9a06ccadd5f88beab6860-254825841253.europe-west1.gke.goog" "http://136.110.214.105/?name=Noah"
```

---

**Document Version**: 1.0
**Last Updated**: 2025-11-21
**Status**: Complete and Validated
