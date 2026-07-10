output "managed_zone_name" {
  description = "Cloud DNS managed zone resource name."
  value       = google_dns_managed_zone.u_rei_com.name
}

output "name_servers" {
  description = "Nameservers Cloud DNS assigned to this zone. Set these at お名前.com during cutover (tasks.md 4.1)."
  value       = google_dns_managed_zone.u_rei_com.name_servers
}
