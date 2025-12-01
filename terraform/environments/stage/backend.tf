# Local Backend Configuration for Test Environment
# State is stored locally in terraform.tfstate file
# WARNING: Not suitable for production or team collaboration

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# For production, use GCS backend:
# terraform {
#   backend "gcs" {
#     bucket = "your-terraform-state-bucket"
#     prefix = "baby-names/test"
#   }
# }
