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

output "vps_private_ip" {
  description = "IP privada del VPS ARM en la red codespartan-internal"
  value       = hcloud_server_network.vps.ip
}

output "apis_private_ip" {
  description = "IP privada del VPS de APIs en la red codespartan-internal"
  value       = hcloud_server_network.vps_apis.ip
}

output "dns_zone_ids" {
  description = "IDs de zonas DNS creadas (si procede)"
  value       = try({ for k, z in hcloud_zone.zones : k => z.id }, {})
}
