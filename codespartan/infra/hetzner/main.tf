terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.48"
    }
    hetznerdns = {
      source  = "timohirt/hetznerdns"
      version = "~> 2.2"
    }
  }
}

provider "hcloud" {
  # Si no pasas token, el provider usa env HCLOUD_TOKEN
  token = var.hcloud_token != "" ? var.hcloud_token : null
}

provider "hetznerdns" {
  apitoken = var.hetzner_dns_token != "" ? var.hetzner_dns_token : null
}

resource "hcloud_ssh_key" "main" {
  name       = var.ssh_key_name
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_firewall" "basic" {
  name = "codespartan-basic"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.firewall_allowed_ssh_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # ICMP entrante (ping/diagnóstico) - opcional, puedes eliminarlo si no lo quieres
  rule {
    direction  = "in"
    protocol   = "icmp"
    port       = "-1"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Salida permitida (por defecto Hetzner la permite, esto es explícito)
  rule {
    direction  = "out"
    protocol   = "icmp"
    port       = "-1"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "vps" {
  name        = var.server_name
  image       = var.image
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.main.id]
  firewall_ids = [hcloud_firewall.basic.id]

  user_data = <<-CLOUD
  #cloud-config
  package_update: true
  package_upgrade: true
  runcmd:
    - |
      set -eux
      if ! command -v docker >/dev/null 2>&1; then
        dnf -y install yum-utils device-mapper-persistent-data lvm2
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        systemctl enable --now docker
      fi
      docker network create web || true
  CLOUD
}

# DNS (opcional): crea zonas y A records para subdominios -> IPv4 del VPS
# Si no usas Hetzner DNS (NS del dominio apuntando a Hetzner), comenta todo este bloque.
locals {
  dns_enabled  = length(var.domains) > 0
  aaaa_enabled = var.create_aaaa_records && var.manual_ipv6_address != ""
  public_ipv4  = var.manual_ipv4_address != "" ? var.manual_ipv4_address : hcloud_server.vps.ipv4_address
}

resource "hetznerdns_zone" "zones" {
  for_each = local.dns_enabled ? toset(var.domains) : []
  name     = each.key
  ttl      = 300
}

# Subdominios (www, staging, lab por defecto) apuntando al VPS
resource "hetznerdns_record" "subs" {
  for_each = local.dns_enabled ? {
    for tuple in flatten([
      for d in var.domains : [
        for s in var.subdomains : {
          domain = d
          sub    = s
        }
      ]
    ]) : "${tuple.domain}_${tuple.sub}" => tuple
  } : {}

  zone_id = hetznerdns_zone.zones[each.value.domain].id
  name    = each.value.sub
  type    = "A"
  value   = local.public_ipv4
  ttl     = 120
}

# AAAA para subdominios (si se habilita y se define IPv6 manual)
resource "hetznerdns_record" "subs_aaaa" {
  for_each = local.dns_enabled && local.aaaa_enabled ? {
    for tuple in flatten([
      for d in var.domains : [
        for s in var.subdomains : {
          domain = d
          sub    = s
        }
      ]
    ]) : "${tuple.domain}_${tuple.sub}" => tuple
  } : {}

  zone_id = hetznerdns_zone.zones[each.value.domain].id
  name    = each.value.sub
  type    = "AAAA"
  value   = var.manual_ipv6_address
  ttl     = 300
}

# Apex/root records condicionales
resource "hetznerdns_record" "apex_a" {
  for_each = local.dns_enabled && var.create_apex_a ? toset(var.domains) : []
  zone_id  = hetznerdns_zone.zones[each.key].id
  name     = var.apex_name
  type     = "A"
  value    = local.public_ipv4
  ttl      = 300
}

resource "hetznerdns_record" "apex_aaaa" {
  for_each = local.dns_enabled && var.create_apex_aaaa && var.manual_ipv6_address != "" ? toset(var.domains) : []
  zone_id  = hetznerdns_zone.zones[each.key].id
  name     = var.apex_name
  type     = "AAAA"
  value    = var.manual_ipv6_address
  ttl      = 300
}

# Expandir registros adicionales (MX/TXT/CNAME/etc.) con clave compuesta
resource "hetznerdns_record" "additional" {
  for_each = local.dns_enabled ? merge([
    for domain, recs in var.dns_additional_records : {
      for i, r in recs : "${domain}_${i}" => merge(r, { domain = domain })
    }
  ]...) : {}

  zone_id = hetznerdns_zone.zones[each.value.domain].id
  name    = each.value.name
  type    = each.value.type
  value   = each.value.value
  ttl     = try(each.value.ttl, 300)
}
