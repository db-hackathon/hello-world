# Database Bootstrap Module

This module grants PostgreSQL permissions to the IAM database user by creating a temporary pod and executing SQL GRANT statements.

## Purpose

Creating a CloudSQL IAM database user only sets up the **authentication layer**. PostgreSQL permissions must be granted separately via SQL. This module automates that process.

## Why This Module Exists

**The Chicken-and-Egg Problem:**
1. Liquibase needs to connect to PostgreSQL as the IAM user
2. Liquibase needs CREATE permission on the public schema to create the `databasechangelog` table
3. But the IAM user doesn't have CREATE permission yet
4. So Liquibase can't run until permissions are granted
5. But we need to grant permissions before Liquibase runs

**Solution:** This module grants all necessary permissions before Helm/Liquibase deployment.

## How It Works

1. Creates a temporary Kubernetes pod with:
   - PostgreSQL client (`postgres:15-alpine`)
   - Cloud SQL Proxy sidecar (for IAM authentication)
2. Resets the postgres user password (random generated)
3. Connects as postgres user (admin)
4. Creates the database (if it doesn't exist)
5. Executes all GRANT statements for the IAM user
6. Verifies permissions
7. Cleans up the temporary pod

## Resources Created

- `random_password.postgres_password` - Random password for postgres user
- `null_resource.database_permissions` - Executes the bootstrap script

## Usage

```hcl
module "database_bootstrap" {
  source = "../../modules/database-bootstrap"

  project_id              = "extended-ascent-477308-m8"
  region                  = "europe-west1"
  cloudsql_instance_name  = "hello-world-manual"
  instance_connection_name = "extended-ascent-477308-m8:europe-west1:hello-world-manual"

  database_name = "baby_names"
  iam_user_email = "hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com"

  namespace            = "baby-names-staging"
  service_account_name = "baby-names-staging"

  temp_pod_name    = "psql-client-terraform"
  timeout_seconds  = 300

  depends_on = [
    module.cloudsql,
    module.k8s_namespace
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | n/a | yes |
| region | GCP region | string | n/a | yes |
| cloudsql_instance_name | Name of the CloudSQL instance | string | n/a | yes |
| instance_connection_name | CloudSQL instance connection name (project:region:instance) | string | n/a | yes |
| database_name | Name of the database | string | n/a | yes |
| iam_user_email | IAM service account email (without .iam suffix) | string | n/a | yes |
| namespace | Kubernetes namespace for temporary pod | string | n/a | yes |
| service_account_name | Kubernetes ServiceAccount name | string | n/a | yes |
| temp_pod_name | Name of the temporary pod | string | "psql-client-terraform" | no |
| timeout_seconds | Timeout for pod readiness and SQL execution | number | 300 | no |

## Outputs

| Name | Description |
|------|-------------|
| bootstrap_completed | Indicates that bootstrap has completed |
| iam_database_user | PostgreSQL username for the IAM user (email with .iam suffix) |
| database_name | Name of the bootstrapped database |

## Dependencies

**Must exist before running this module:**
- CloudSQL instance with IAM authentication enabled
- CloudSQL IAM database user created
- Kubernetes namespace
- Kubernetes ServiceAccount with Workload Identity
- RBAC permissions (pod creation, exec)
- ImagePullSecret (to pull postgres:15-alpine and cloud-sql-proxy images)

## Permissions Required

**Terraform execution service account:**
- `roles/container.admin` - To get GKE credentials and execute kubectl commands

**GCP service account (used by temporary pod):**
- `roles/cloudsql.client` - To connect to CloudSQL
- `roles/cloudsql.instanceUser` - To authenticate as IAM user

**Kubernetes ServiceAccount:**
- Workload Identity annotation linking to GCP service account
- Ability to create pods in the namespace (typically cluster-admin via Terraform)

## PostgreSQL Permissions Granted

The script grants the following permissions to the IAM user:

```sql
-- Database-level
GRANT ALL PRIVILEGES ON DATABASE {database_name} TO "{iam_user_email}.iam";

-- Schema-level
GRANT ALL ON SCHEMA public TO "{iam_user_email}.iam";
GRANT CREATE ON SCHEMA public TO "{iam_user_email}.iam";  -- Required for Liquibase

-- Object-level (existing objects)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "{iam_user_email}.iam";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "{iam_user_email}.iam";

-- Default privileges (future objects created by postgres)
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT ALL ON TABLES TO "{iam_user_email}.iam";

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT ALL ON SEQUENCES TO "{iam_user_email}.iam";

-- Default privileges (future objects created by IAM user itself)
ALTER DEFAULT PRIVILEGES FOR ROLE "{iam_user_email}.iam" IN SCHEMA public
GRANT ALL ON TABLES TO "{iam_user_email}.iam";

ALTER DEFAULT PRIVILEGES FOR ROLE "{iam_user_email}.iam" IN SCHEMA public
GRANT ALL ON SEQUENCES TO "{iam_user_email}.iam";
```

## Execution Time

- Typical execution: **30-60 seconds**
- Breakdown:
  - Pod creation: 10-20 seconds
  - Cloud SQL Proxy startup: 5-10 seconds
  - SQL execution: 5-10 seconds
  - Cleanup: 5-10 seconds

## Triggers for Re-execution

The bootstrap script re-runs if any of these change:
- IAM user email
- Database name
- Instance connection name
- Namespace or ServiceAccount name
- Script content (SHA256 hash)

## Troubleshooting

### Pod fails to become ready

**Symptoms:**
```
Error: Pod failed to become ready within 300 seconds
```

**Possible causes:**
1. Cloud SQL Proxy can't connect to instance
   - Check Workload Identity binding
   - Verify IAM roles (cloudsql.client, cloudsql.instanceUser)
   - Check instance connection name is correct
2. Image pull failures
   - Verify ImagePullSecret exists and is valid
   - Check Cloud NAT is configured (for private clusters)

**Debug:**
```bash
kubectl describe pod psql-client-terraform -n baby-names-staging
kubectl logs psql-client-terraform -n baby-names-staging -c cloud-sql-proxy
```

### Failed to set postgres user password

**Symptoms:**
```
ERROR: Failed to set postgres user password
```

**Possible causes:**
1. Terraform execution SA lacks permissions
   - Needs `roles/cloudsql.admin` or similar
2. CloudSQL instance doesn't exist
3. Postgres user doesn't exist (shouldn't happen, postgres is default)

**Debug:**
```bash
gcloud sql users list --instance=hello-world-manual --project=extended-ascent-477308-m8
```

### Permission denied errors during GRANT statements

**Symptoms:**
```
ERROR: permission denied for database baby_names
```

**Possible causes:**
1. Postgres user password is incorrect
2. CloudSQL Proxy connection failed
3. Database doesn't exist

**Debug:**
```bash
# Check postgres user can connect
kubectl exec -n baby-names-staging psql-client-terraform -c psql-client -- \
  env PGPASSWORD='<password>' \
  psql -h localhost -U postgres -d postgres -c '\l'
```

### Temporary pod not cleaned up

**Symptoms:**
Pod still exists after Terraform completes

**Manual cleanup:**
```bash
kubectl delete pod psql-client-terraform -n baby-names-staging
```

## Important Notes

1. **Postgres Password Security**: The random password is stored in Terraform state. Ensure state is encrypted (e.g., Terraform Cloud).

2. **Idempotency**: The script is idempotent - it can be run multiple times safely. GRANT statements are cumulative.

3. **Database Creation**: The script creates the database if it doesn't exist. If it exists, it's a no-op.

4. **Re-running**: To force a re-run, use `terraform taint null_resource.database_permissions`

5. **Cleanup**: The temporary pod is automatically deleted on success or failure via the cleanup trap.

## Alternative Approaches (Not Used)

### Why not Terraform google_sql_database resource?
- Doesn't support GRANT statements
- Only manages database creation, not permissions

### Why not Terraform PostgreSQL provider?
- Requires direct database connection from Terraform
- Difficult to set up with CloudSQL IAM authentication
- Requires exposing database connection details

### Why not Liquibase changesets?
- Chicken-and-egg: IAM user needs CREATE permission before Liquibase can run
- Liquibase runs as the IAM user, can't grant permissions to itself
- Bootstrap must happen before application deployment

## Security Considerations

1. **Temporary Credentials**: Postgres password is only used during bootstrap and is randomly generated
2. **Workload Identity**: Uses GCP IAM for authentication, not long-lived credentials
3. **Least Privilege**: Temporary pod uses application ServiceAccount (not cluster-admin)
4. **Cleanup**: Pod is deleted after execution, not left running
5. **Audit Trail**: All SQL commands are logged in script output
