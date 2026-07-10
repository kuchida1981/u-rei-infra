variable "project_id" {
  description = "Existing shared GCP project ID (kuchida-devel) the Cloud DNS zone lives in."
  type        = string
}

variable "region" {
  description = "Region for the Google provider. Cloud DNS itself is a global service, unaffected by this value."
  type        = string
  default     = "us-west1"
}

variable "domain" {
  description = "Domain this repository owns the Cloud DNS managed zone for."
  type        = string
  default     = "u-rei.com"
}

variable "record_ttl" {
  description = "TTL (seconds) applied to all record sets below, matching the previous お名前.com zone."
  type        = number
  default     = 3600
}

variable "github_pages_ips" {
  description = "GitHub Pages' well-known IPv4 addresses backing the apex A record (kuchida1981.github.io user site)."
  type        = list(string)
  default = [
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153",
  ]
}

variable "github_pages_cname" {
  description = "CNAME target shared by www (kuchida1981.github.io blog) and skk (web-skk project pages). GitHub Pages routes by Host header to the right repo, so both subdomains point at the same user-site CNAME."
  type        = string
  default     = "kuchida1981.github.io."
}

variable "n8n_ip" {
  description = "n8n-ops' static external IP (its terraform/main `vm_external_ip` output). Source of truth is n8n-ops; update here via a manual PR if it ever changes."
  type        = string
  default     = "34.169.127.42"
}

variable "vaultwarden_ip" {
  description = "vaultwarden-hosting's static external IP. Source of truth is vaultwarden-hosting; update here via a manual PR if it ever changes."
  type        = string
  default     = "34.84.31.142"
}

variable "brevo_dkim1_target" {
  description = "Brevo DKIM selector 1 CNAME target, for n8n's outbound mail domain authentication."
  type        = string
  default     = "b1.u-rei-com.dkim.brevo.com."
}

variable "brevo_dkim2_target" {
  description = "Brevo DKIM selector 2 CNAME target, for n8n's outbound mail domain authentication."
  type        = string
  default     = "b2.u-rei-com.dkim.brevo.com."
}

variable "brevo_domain_verification_txt" {
  description = "Brevo domain-ownership verification TXT value (unquoted; the record wraps it in quotes)."
  type        = string
  default     = "brevo-code:1c77d23b76bfea2ca29505578fd48451"
}

variable "dmarc_record" {
  description = "DMARC policy TXT value for _dmarc.u-rei.com (unquoted; the record wraps it in quotes)."
  type        = string
  default     = "v=DMARC1; p=none; rua=mailto:rua@dmarc.brevo.com"
}
