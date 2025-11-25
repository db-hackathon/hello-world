# CloudSQL Module

This module creates a CloudSQL PostgreSQL instance with IAM authentication enabled and configures the database and IAM user.

## Features

- **IAM Authentication**: Passwordless authentication using GCP service accounts
- **Automated Backups**: Point-in-time recovery with configurable retention
- **High Availability**: Optional regional configuration for HA
- **Secure by Default**: IAM authentication flag enabled, SSL optional
- **Query Insights**: Optional query performance monitoring

## Resources Created

- `google_sql_database_instance.main` - CloudSQL PostgreSQL instance
- `google_sql_database.baby_names` - Application database
- `google_sql_user.iam_user` - IAM service account database user

## Usage

```hcl
module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id    = "extended-ascent-477308-m8"
  instance_name = "hello-world-manual"
  region        = "europe-west1"

  # Instance configuration
  tier               = "db-custom-2-8192"  # 2 vCPU, 8GB RAM
  availability_type  = "ZONAL"             # or "REGIONAL" for HA
  disk_type          = "PD_SSD"
  disk_size          = 10
  disk_autoresize    = true
  deletion_protection = true

  # Database
  database_name = "baby_names"

  # IAM user (must match GCP service account email)
  iam_user_email = "hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com"

  # Backup configuration
  backup_start_time                  = "03:00"
  enable_point_in_time_recovery      = true
  transaction_log_retention_days     = 7
  retained_backups                   = 7

  # Network (optional)
  enable_public_ip = true
  require_ssl      = false  # IAM auth provides security

  # Maintenance
  maintenance_window_day  = 7  # Sunday
  maintenance_window_hour = 3  # 3 AM
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | n/a | yes |
| instance_name | Name of the CloudSQL instance | string | n/a | yes |
| use_random_suffix | Add random suffix to instance name | bool | false | no |
| database_version | PostgreSQL version | string | "POSTGRES_17" | no |
| region | GCP region | string | "europe-west1" | no |
| tier | Machine tier | string | "db-custom-2-8192" | no |
| availability_type | Availability type (ZONAL, REGIONAL) | string | "ZONAL" | no |
| disk_type | Disk type (PD_SSD, PD_HDD) | string | "PD_SSD" | no |
| disk_size | Disk size in GB | number | 10 | no |
| disk_autoresize | Enable automatic disk resize | bool | true | no |
| deletion_protection | Enable deletion protection | bool | true | no |
| backup_start_time | Backup start time (HH:MM) | string | "03:00" | no |
| enable_point_in_time_recovery | Enable PITR | bool | true | no |
| transaction_log_retention_days | Transaction log retention days | number | 7 | no |
| retained_backups | Number of backups to retain | number | 7 | no |
| maintenance_window_day | Maintenance day (1-7) | number | 7 | no |
| maintenance_window_hour | Maintenance hour (0-23) | number | 3 | no |
| maintenance_update_track | Update track (stable, canary) | string | "stable" | no |
| enable_public_ip | Enable public IP | bool | true | no |
| private_network | VPC network for private IP | string | null | no |
| require_ssl | Require SSL connections | bool | false | no |
| authorized_networks | Authorized networks for public IP | list(object) | [] | no |
| enable_query_insights | Enable query insights | bool | false | no |
| database_name | Database name to create | string | "baby_names" | no |
| iam_user_email | IAM service account email for database access | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance_name | Name of the CloudSQL instance |
| instance_connection_name | Connection name for Cloud SQL Proxy |
| instance_self_link | Self link of the instance |
| instance_ip_addresses | All IP addresses of the instance |
| public_ip_address | Public IP address |
| database_version | PostgreSQL version |
| database_name | Name of the created database |
| iam_user_name | Name of the IAM database user |
| iam_database_user | Full IAM database user name (for DB_USER env var) |
| region | Region of the instance |
| tier | Machine tier |

## Dependencies

- **GCP Service Account**: IAM user email must be from an existing service account
- **Cloud SQL Admin API**: Must be enabled

## Permissions Required

The Terraform execution service account needs:
- `roles/cloudsql.admin` - To create and manage CloudSQL instances

## Provisioning Time

- Initial instance creation: **5-10 minutes**
- Instance restart (when changing flags): **3-5 minutes**

## CRITICAL: IAM Authentication Flag

The `cloudsql.iam_authentication=on` database flag is **MANDATORY** for IAM-based authentication. Without this flag, IAM authentication will fail even if all other configuration is correct.

**Important Notes:**
1. **Instance Restart**: Enabling this flag triggers an instance restart (3-5 minutes downtime)
2. **Lifecycle Management**: The module uses `ignore_changes` for `database_flags` to prevent unnecessary restarts. Remove this if you need to modify flags.
3. **First Apply**: The flag is set during initial creation, so no restart occurs on first apply.

## PostgreSQL Permissions

**Important**: Creating the IAM database user only sets up the authentication layer. PostgreSQL permissions must be granted separately using the `database-bootstrap` module.

Required PostgreSQL grants:
```sql
GRANT ALL PRIVILEGES ON DATABASE baby_names TO "{iam_user_email}.iam";
GRANT ALL ON SCHEMA public TO "{iam_user_email}.iam";
GRANT CREATE ON SCHEMA public TO "{iam_user_email}.iam";
-- Plus default privileges (see database-bootstrap module)
```

## Database User Format

The IAM database user created by CloudSQL has the format:
- **CloudSQL user**: `hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com`
- **PostgreSQL user**: `hello-world-staging@extended-ascent-477308-m8.iam.gserviceaccount.com.iam`

Note the `.iam` suffix added by CloudSQL for IAM users.

## Connection Methods

**From GKE pods (using Cloud SQL Proxy):**
```yaml
containers:
- name: cloud-sql-proxy
  image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
  args:
    - "--auto-iam-authn"
    - "--structured-logs"
    - "--port=5432"
    - "{instance_connection_name}"
```

**Connection string:**
- Host: `localhost` (via proxy)
- Port: `5432`
- Database: `baby_names`
- User: `{iam_user_email}.iam`
- Password: None (IAM authentication)
