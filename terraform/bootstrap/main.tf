# Ensures the required APIs are enabled on the existing shared project.
# All of these are typically already enabled (this project also hosts
# n8n-ops and vaultwarden-hosting), but declaring them keeps this repo
# self-contained if it's ever pointed at a different project.
resource "google_project_service" "required" {
  for_each = toset([
    "dns.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Remote state bucket used by terraform/main.
resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_id}-dns-tfstate"
  project                     = var.project_id
  location                    = upper(var.region)
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required]
}

# Workload Identity Federation: lets GitHub Actions authenticate to GCP
# without a long-lived service account key.
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool-dns"
  display_name              = "GitHub Actions (u-rei.com-dns)"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # Only this exact repository may mint tokens through this provider.
  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service account impersonated by GitHub Actions to run terraform/main.
resource "google_service_account" "terraform_ci" {
  project      = var.project_id
  account_id   = "terraform-ci-dns"
  display_name = "Terraform CI for u-rei.com-dns (GitHub Actions)"
}

resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.terraform_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

resource "google_storage_bucket_iam_member" "terraform_ci_state_access" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# DNS-scoped role for managing the managed zone and record sets created by
# terraform/main. This project also hosts unrelated services (BigQuery,
# Firebase, etc.) for other work, so this CI service account is deliberately
# not granted any broader project role.
resource "google_project_iam_member" "terraform_ci_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}
