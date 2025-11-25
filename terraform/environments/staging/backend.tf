# Terraform Cloud Backend Configuration
#
# Configure your Terraform Cloud workspace:
# 1. Create a workspace named "baby-names-staging" in your Terraform Cloud organization
# 2. Set environment variable: GOOGLE_CREDENTIALS (service account key JSON)
# 3. Set Terraform variables for sensitive values (registry_password, etc.)
#
# To use this backend:
# 1. Update the organization name below
# 2. Run: terraform login
# 3. Run: terraform init

terraform {
  cloud {
    # TODO: Replace with your Terraform Cloud organization name
    organization = "your-org-name"

    workspaces {
      name = "baby-names-staging"
    }
  }
}

# Alternative: Local backend (for testing)
# Uncomment to use local state instead of Terraform Cloud
#
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }

# Alternative: GCS backend
# Uncomment to use Google Cloud Storage for state
#
# terraform {
#   backend "gcs" {
#     bucket = "your-terraform-state-bucket"
#     prefix = "baby-names/staging"
#   }
# }
