# Database Bootstrap Module
# Grants PostgreSQL permissions to IAM user via temporary pod

terraform {
  required_version = ">= 1.5"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Generate random password for postgres user (used only for bootstrap)
# Note: override_special limits to shell-safe characters to avoid issues
# when the password is passed through kubectl exec and bash commands
resource "random_password" "postgres_password" {
  length           = 32
  special          = true
  override_special = "_-+="
}

# Bootstrap database permissions
resource "null_resource" "database_permissions" {
  # Trigger re-run if any of these values change
  triggers = {
    iam_user_email           = var.iam_user_email
    database_name            = var.database_name
    instance_connection_name = var.instance_connection_name
    namespace                = var.namespace
    service_account_name     = var.service_account_name
    temp_pod_name            = var.temp_pod_name
    script_hash              = filesha256("${path.module}/scripts/setup-db-permissions.sh")
  }

  # Run the bootstrap script
  provisioner "local-exec" {
    command     = "${path.module}/scripts/setup-db-permissions.sh"
    interpreter = ["/bin/bash"]

    environment = {
      PROJECT_ID               = var.project_id
      REGION                   = var.region
      CLOUDSQL_INSTANCE        = var.cloudsql_instance_name
      INSTANCE_CONNECTION_NAME = var.instance_connection_name
      DATABASE_NAME            = var.database_name
      IAM_USER_EMAIL           = var.iam_user_email
      NAMESPACE                = var.namespace
      K8S_SA_NAME              = var.service_account_name
      POSTGRES_PASSWORD        = random_password.postgres_password.result
      POD_NAME                 = var.temp_pod_name
      TIMEOUT_SECONDS          = var.timeout_seconds
    }
  }

  # Clean up on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete pod ${self.triggers.temp_pod_name} -n ${self.triggers.namespace} --ignore-not-found=true"
  }
}
