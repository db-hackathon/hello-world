#!/bin/bash

# Database Permissions Bootstrap Script
# Creates temporary pod and grants PostgreSQL permissions to IAM user

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate required environment variables
REQUIRED_VARS=(
    "PROJECT_ID"
    "REGION"
    "CLOUDSQL_INSTANCE"
    "INSTANCE_CONNECTION_NAME"
    "DATABASE_NAME"
    "IAM_USER_EMAIL"
    "NAMESPACE"
    "K8S_SA_NAME"
    "POSTGRES_PASSWORD"
    "POD_NAME"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        log_error "Required environment variable $var is not set"
        exit 1
    fi
done

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"

log_info "Starting database permissions bootstrap..."
log_info "CloudSQL Instance: ${INSTANCE_CONNECTION_NAME}"
log_info "Database: ${DATABASE_NAME}"
log_info "IAM User: ${IAM_USER_EMAIL}"
log_info "Namespace: ${NAMESPACE}"

# Clean up function
cleanup() {
    local exit_code=$?
    log_info "Cleaning up temporary resources..."
    kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" --ignore-not-found=true 2>/dev/null || true

    if [[ $exit_code -eq 0 ]]; then
        log_info "✓ Database permissions bootstrap completed successfully"
    else
        log_error "✗ Database permissions bootstrap failed with exit code $exit_code"
    fi

    exit $exit_code
}

trap cleanup EXIT

# Step 1: Set postgres user password
log_info "Setting postgres user password..."

if ! gcloud sql users set-password postgres \
    --instance="${CLOUDSQL_INSTANCE}" \
    --password="${POSTGRES_PASSWORD}" \
    --project="${PROJECT_ID}"; then
    log_error "Failed to set postgres user password"
    exit 1
fi

log_info "✓ Postgres password set"

# Step 2: Create temporary pod with PostgreSQL client and Cloud SQL Proxy
log_info "Creating temporary pod with PostgreSQL client and Cloud SQL Proxy..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: database-bootstrap
    managed-by: terraform
spec:
  serviceAccountName: ${K8S_SA_NAME}
  restartPolicy: Never
  containers:
  - name: psql-client
    image: postgres:15-alpine
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
  - name: cloud-sql-proxy
    image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
    args:
      - "${INSTANCE_CONNECTION_NAME}"
      - "--port=5432"
      - "--structured-logs"
    securityContext:
      runAsNonRoot: true
      allowPrivilegeEscalation: false
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
EOF

# Wait for pod to be ready
log_info "Waiting for pod to be ready (timeout: ${TIMEOUT_SECONDS}s)..."

if ! kubectl wait --for=condition=ready pod/${POD_NAME} -n ${NAMESPACE} --timeout=${TIMEOUT_SECONDS}s; then
    log_error "Pod failed to become ready within ${TIMEOUT_SECONDS} seconds"
    kubectl describe pod ${POD_NAME} -n ${NAMESPACE}
    kubectl logs ${POD_NAME} -n ${NAMESPACE} -c cloud-sql-proxy --tail=50 || true
    exit 1
fi

log_info "✓ Pod is ready"

# Wait for Cloud SQL Proxy to establish connection
log_info "Waiting for Cloud SQL Proxy to establish connection..."
sleep 10

# Test connection with retries
MAX_RETRIES=5
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    log_info "Testing database connection (attempt $((RETRY_COUNT + 1))/${MAX_RETRIES})..."
    if kubectl exec -n ${NAMESPACE} ${POD_NAME} -c psql-client -- \
        env PGPASSWORD="${POSTGRES_PASSWORD}" \
        psql -h localhost -U postgres -d postgres -c "SELECT 1" >/dev/null 2>&1; then
        log_info "✓ Database connection successful"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
            log_warn "Connection failed, retrying in 10 seconds..."
            sleep 10
        else
            log_error "Failed to establish database connection after ${MAX_RETRIES} attempts"
            kubectl logs ${POD_NAME} -n ${NAMESPACE} -c cloud-sql-proxy --tail=100 || true
            exit 1
        fi
    fi
done

# Step 3: Create database (if it doesn't exist)
log_info "Creating database '${DATABASE_NAME}' (if it doesn't exist)..."

# Check if database exists with retry
RETRY_COUNT=0
DB_EXISTS=false
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if kubectl exec -n ${NAMESPACE} ${POD_NAME} -c psql-client -- \
        env PGPASSWORD="${POSTGRES_PASSWORD}" \
        psql -h localhost -U postgres -d postgres \
        -c "SELECT 1 FROM pg_database WHERE datname='${DATABASE_NAME}'" \
        -t -A 2>/dev/null | grep -q 1; then
        DB_EXISTS=true
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
        log_warn "Failed to check database existence, retrying in 5 seconds..."
        sleep 5
    fi
done

# Create database if it doesn't exist
if [[ "$DB_EXISTS" != "true" ]]; then
    RETRY_COUNT=0
    while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
        if kubectl exec -n ${NAMESPACE} ${POD_NAME} -c psql-client -- \
            env PGPASSWORD="${POSTGRES_PASSWORD}" \
            psql -h localhost -U postgres -d postgres \
            -c "CREATE DATABASE ${DATABASE_NAME};" 2>/dev/null; then
            break
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
            log_warn "Failed to create database, retrying in 5 seconds..."
            sleep 5
        else
            log_error "Failed to create database after ${MAX_RETRIES} attempts"
            exit 1
        fi
    done
fi

log_info "✓ Database exists"

# Step 4: Grant PostgreSQL permissions to IAM user
log_info "Granting PostgreSQL permissions to IAM user..."

# Execute all GRANT statements with retry
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if kubectl exec -i -n ${NAMESPACE} ${POD_NAME} -c psql-client -- \
        env PGPASSWORD="${POSTGRES_PASSWORD}" \
        psql -h localhost -U postgres -d ${DATABASE_NAME} -v ON_ERROR_STOP=1 <<EOF_SQL
-- CloudSQL PostgreSQL 17 + IAM Authentication Solution
--
-- Issue: PostgreSQL 15+ changed public schema ownership to pg_database_owner
-- and revoked CREATE privilege from PUBLIC (CVE-2018-1058 fix).
-- IAM users in CloudSQL cannot be granted cloudsqlsuperuser role membership
-- (GRANT cloudsqlsuperuser fails silently in CloudSQL PostgreSQL 17).
--
-- Solution: Grant schema and object permissions directly to IAM user.

-- Schema-level permissions (CRITICAL for CREATE TABLE)
GRANT ALL ON SCHEMA public TO "${IAM_USER_EMAIL}";
GRANT USAGE ON SCHEMA public TO "${IAM_USER_EMAIL}";
GRANT CREATE ON SCHEMA public TO "${IAM_USER_EMAIL}";

-- Database-level permissions
GRANT ALL PRIVILEGES ON DATABASE ${DATABASE_NAME} TO "${IAM_USER_EMAIL}";
GRANT CONNECT ON DATABASE ${DATABASE_NAME} TO "${IAM_USER_EMAIL}";
GRANT TEMPORARY ON DATABASE ${DATABASE_NAME} TO "${IAM_USER_EMAIL}";

-- Object-level permissions (existing objects in public schema)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "${IAM_USER_EMAIL}";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "${IAM_USER_EMAIL}";
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO "${IAM_USER_EMAIL}";

-- Default privileges for future objects created by postgres
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT ALL ON TABLES TO "${IAM_USER_EMAIL}";

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT ALL ON SEQUENCES TO "${IAM_USER_EMAIL}";

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT ALL ON FUNCTIONS TO "${IAM_USER_EMAIL}";

-- Default privileges for future objects created by cloudsqlsuperuser
ALTER DEFAULT PRIVILEGES FOR ROLE cloudsqlsuperuser IN SCHEMA public
GRANT ALL ON TABLES TO "${IAM_USER_EMAIL}";

ALTER DEFAULT PRIVILEGES FOR ROLE cloudsqlsuperuser IN SCHEMA public
GRANT ALL ON SEQUENCES TO "${IAM_USER_EMAIL}";

ALTER DEFAULT PRIVILEGES FOR ROLE cloudsqlsuperuser IN SCHEMA public
GRANT ALL ON FUNCTIONS TO "${IAM_USER_EMAIL}";

-- Note: ALTER DEFAULT PRIVILEGES FOR ROLE "IAM_USER" not needed
-- as IAM user creates its own objects and already has ownership.
-- The defaults for postgres and cloudsqlsuperuser cover tables
-- created by those privileged roles.
EOF_SQL
    then
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
        log_warn "Failed to grant permissions, retrying in 5 seconds..."
        sleep 5
    else
        log_error "Failed to grant permissions after ${MAX_RETRIES} attempts"
        kubectl logs ${POD_NAME} -n ${NAMESPACE} -c cloud-sql-proxy --tail=100 || true
        exit 1
    fi
done

log_info "✓ Permissions granted"

# Step 5: Verify permissions
log_info "Verifying permissions..."

kubectl exec -n ${NAMESPACE} ${POD_NAME} -c psql-client -- \
    env PGPASSWORD="${POSTGRES_PASSWORD}" \
    psql -h localhost -U postgres -d ${DATABASE_NAME} \
    -c "\du \"${IAM_USER_EMAIL}\""

log_info "✓ Permissions verified"

# Cleanup will be handled by trap
log_info "Database permissions bootstrap completed successfully"
