variable "tailscale_tailnet" {
  description = "Tailscale tailnet identifier (e.g. example.ts.net or an org name)."
  type        = string
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID with the Policy File (write) scope. Dedicated to this repository; the service repositories' clients only hold Auth Keys."
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret paired with tailscale_oauth_client_id."
  type        = string
  sensitive   = true
}
