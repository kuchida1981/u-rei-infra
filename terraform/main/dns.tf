# u-rei.com is a shared domain across four independent repos (n8n-ops,
# vaultwarden-hosting, kuchida1981.github.io, web-skk). This repo is the
# sole owner of the zone and every record below - see
# openspec/project.md's "DNSレコード所有のポリシー" for why cross-repo
# Terraform coupling was deliberately avoided in favor of this central
# ownership plus manual update PRs.
resource "google_dns_managed_zone" "u_rei_com" {
  project     = var.project_id
  name        = "u-rei-com"
  dns_name    = "${var.domain}."
  description = "u-rei.com - managed centrally by u-rei.com-dns."
}

# apex (u-rei.com) -> GitHub Pages, backing kuchida1981.github.io's user site.
resource "google_dns_record_set" "apex_a" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.u_rei_com.name
  name         = google_dns_managed_zone.u_rei_com.dns_name
  type         = "A"
  ttl          = var.record_ttl
  rrdatas      = var.github_pages_ips
}

resource "google_dns_record_set" "www_cname" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.u_rei_com.name
  name         = "www.${google_dns_managed_zone.u_rei_com.dns_name}"
  type         = "CNAME"
  ttl          = var.record_ttl
  rrdatas      = [var.github_pages_cname]
}

# skk.u-rei.com actually serves web-skk's GitHub Pages project site; GitHub
# routes by Host header, not by which repo the CNAME target names.
resource "google_dns_record_set" "skk_cname" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.u_rei_com.name
  name         = "skk.${google_dns_managed_zone.u_rei_com.dns_name}"
  type         = "CNAME"
  ttl          = var.record_ttl
  rrdatas      = [var.github_pages_cname]
}

resource "google_dns_record_set" "n8n_a" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.u_rei_com.name
  name         = "n8n.${google_dns_managed_zone.u_rei_com.dns_name}"
  type         = "A"
  ttl          = var.record_ttl
  rrdatas      = [var.n8n_ip]
}

resource "google_dns_record_set" "vaultwarden_a" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.u_rei_com.name
  name         = "vaultwarden.${google_dns_managed_zone.u_rei_com.dns_name}"
  type         = "A"
  ttl          = var.record_ttl
  rrdatas      = [var.vaultwarden_ip]
}

# Brevo DKIM/domain-verification/DMARC records for n8n's outbound mail.
resource "google_dns_record_set" "brevo_dkim1" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.u_rei_com.name
  name         = "brevo1._domainkey.${google_dns_managed_zone.u_rei_com.dns_name}"
  type         = "CNAME"
  ttl          = var.record_ttl
  rrdatas      = [var.brevo_dkim1_target]
}

resource "google_dns_record_set" "brevo_dkim2" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.u_rei_com.name
  name         = "brevo2._domainkey.${google_dns_managed_zone.u_rei_com.dns_name}"
  type         = "CNAME"
  ttl          = var.record_ttl
  rrdatas      = [var.brevo_dkim2_target]
}

resource "google_dns_record_set" "apex_txt" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.u_rei_com.name
  name         = google_dns_managed_zone.u_rei_com.dns_name
  type         = "TXT"
  ttl          = var.record_ttl
  rrdatas = [
    "\"${var.brevo_domain_verification_txt}\"",
    "\"${var.google_site_verification_txt}\"",
  ]
}

resource "google_dns_record_set" "dmarc_txt" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.u_rei_com.name
  name         = "_dmarc.${google_dns_managed_zone.u_rei_com.dns_name}"
  type         = "TXT"
  ttl          = var.record_ttl
  rrdatas      = ["\"${var.dmarc_record}\""]
}
