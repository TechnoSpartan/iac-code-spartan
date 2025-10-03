output "ipv4" {
  description = "IPv4 pública del VPS"
  value       = hcloud_server.vps.ipv4_address
}

output "server_id" {
  value = hcloud_server.vps.id
}

output "dns_zone_ids" {
  description = "IDs de zonas DNS creadas (si procede)"
  value       = try({ for k, z in hetznerdns_zone.zones : k => z.id }, {})
}
