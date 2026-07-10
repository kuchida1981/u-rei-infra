terraform {
  required_version = ">= 1.6.0"

  backend "gcs" {
    # bucket is supplied at `terraform init` time via -backend-config,
    # using the state_bucket output from terraform/bootstrap.
    prefix = "dns/main"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
