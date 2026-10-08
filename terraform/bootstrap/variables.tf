variable "project_id" {
  description = "Existing shared GCP project ID (kuchida-devel, also used by n8n-ops and vaultwarden-hosting) to provision this repo's WIF pool, CI service account, and tfstate bucket in. This config does not create a new GCP project."
  type        = string
}

variable "region" {
  description = "Default region for regional resources (state bucket)."
  type        = string
  default     = "us-west1"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the Terraform CI service account, in \"owner/repo\" form."
  type        = string
  default     = "kuchida1981/u-rei.com-dns"
}

variable "github_repo_renamed" {
  description = "TEMPORARY (tailscale-acl-ownership): the repository's new name, allowed alongside github_repo during the GitHub rename. Becomes the new github_repo default in task 2.5."
  type        = string
  default     = "kuchida1981/u-rei-infra"
}
