terraform {
  required_version = ">= 1.7.0"

  backend "gcs" {
    # bucket is supplied at `terraform init` time via -backend-config,
    # using the state_bucket output from terraform/bootstrap.
    prefix = "tailscale/main"
  }

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.17"
    }
  }
}

provider "tailscale" {
  tailnet             = var.tailscale_tailnet
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
}
