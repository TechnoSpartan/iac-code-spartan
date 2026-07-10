output "ipv4" {
  description = "IPv4 pública del VPS"
  value       = hcloud_server.vps.ipv4_address
}

output "server_id" {
  value = hcloud_server.vps.id
}

output "apis_ipv4" {
  description = "IPv4 pública del segundo VPS (tier APIs/BBDD)"
  value       = hcloud_server.vps_apis.ipv4_address
}

output "apis_server_id" {
  value = hcloud_server.vps_apis.id
}

output "dns_zone_ids" {
  description = "IDs de zonas DNS creadas (si procede)"
  value       = try({ for k, z in hcloud_zone.zones : k => z.id }, {})
}
