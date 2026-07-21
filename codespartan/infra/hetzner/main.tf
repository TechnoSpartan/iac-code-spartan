terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      # DNS (hcloud_zone / hcloud_zone_rrset) requiere >= 1.54; el antiguo
      # provider timohirt/hetznerdns dejó de funcionar cuando Hetzner cerró
      # dns.hetzner.com (mayo 2026) y movió DNS a la API de Cloud.
      version = "~> 1.54"
    }
  }
}

provider "hcloud" {
  # Si no pasas token, el provider usa env HCLOUD_TOKEN
  # El mismo token de Cloud ahora también gestiona DNS (zonas/rrsets).
  token = var.hcloud_token != "" ? var.hcloud_token : null
}

# Lógica para SSH key: usar contenido inline si está disponible, sino archivo local
locals {
  ssh_public_key = var.ssh_public_key_content != "" ? var.ssh_public_key_content : file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_ssh_key" "main" {
  name       = var.ssh_key_name
  public_key = local.ssh_public_key
}

# Clave dedicada al usuario "deploy" (no-root) del segundo VPS (tier APIs/BBDD),
# aislada de la clave del ARM: si se filtra, el radio de impacto queda
# limitado a esta máquina.
resource "hcloud_ssh_key" "apis_deploy" {
  name       = "codespartan-apis-deploy"
  public_key = var.apis_deploy_ssh_public_key_content
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

  # ICMP entrante (ping/diagnóstico) - sin especificar puerto
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Reglas de salida (outbound)
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "80"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "443"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "53"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "53"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  # NTP for time synchronization
  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "123"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  # SMTP port 587 for email notifications (Authelia, etc.)
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "587"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}

locals {
  cloud_init = <<-CLOUD
  #cloud-config
  package_update: true
  package_upgrade: true
  runcmd:
    - |
      set -eux
      # Install Docker if not present
      if ! command -v docker >/dev/null 2>&1; then
        dnf -y install yum-utils device-mapper-persistent-data lvm2
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        systemctl enable --now docker
      fi
      docker network create web || true

      # firewalld picks the FORWARD-chain zone by a packet's source IP /
      # ingress interface, not its egress interface. Traffic forwarded from
      # containers on the 'web' bridge (172.18.0.0/16) to the private
      # Hetzner network (codespartan-internal, 10.0.0.0/24) ingresses via
      # the bridge, not eth0/eth1, so without this it falls through to the
      # public zone's default and gets rejected even though Docker's own
      # FORWARD rules already allow it unconditionally for this bridge.
      if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --zone=trusted --add-source=172.18.0.0/16 || true
        firewall-cmd --reload || true
      fi

      # Install and configure Fail2ban for SSH protection
      if ! command -v fail2ban-server >/dev/null 2>&1; then
        dnf -y install epel-release
        dnf -y install fail2ban fail2ban-systemd

        # Create custom jail configuration
        cat > /etc/fail2ban/jail.local << 'EOF'
      [DEFAULT]
      bantime = 10m
      findtime = 10m
      maxretry = 5

      [sshd]
      enabled = true
      port = ssh
      logpath = /var/log/secure
      maxretry = 5
      bantime = 10m
      findtime = 10m

      [sshd-ddos]
      enabled = true
      port = ssh
      logpath = /var/log/secure
      maxretry = 10
      findtime = 10m
      bantime = 10m
      EOF

        # Enable and start fail2ban
        systemctl enable fail2ban
        systemctl start fail2ban
      fi
  CLOUD

  # Igual que cloud_init, pero añade un usuario "deploy" sin privilegios de
  # root (solo en el grupo docker) con su propia clave SSH, para aislar el
  # acceso de automatización de este VPS del resto.
  cloud_init_apis = <<-CLOUD
  #cloud-config
  package_update: true
  package_upgrade: true
  users:
    - default
    - name: deploy
      shell: /bin/bash
      ssh_authorized_keys:
        - "${var.apis_deploy_ssh_public_key_content}"
  runcmd:
    - |
      set -eux
      # Install Docker if not present
      if ! command -v docker >/dev/null 2>&1; then
        dnf -y install yum-utils device-mapper-persistent-data lvm2
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        systemctl enable --now docker
      fi
      docker network create web || true
      usermod -aG docker deploy

      # Install and configure Fail2ban for SSH protection
      if ! command -v fail2ban-server >/dev/null 2>&1; then
        dnf -y install epel-release
        dnf -y install fail2ban fail2ban-systemd

        # Create custom jail configuration
        cat > /etc/fail2ban/jail.local << 'EOF'
      [DEFAULT]
      bantime = 10m
      findtime = 10m
      maxretry = 5

      [sshd]
      enabled = true
      port = ssh
      logpath = /var/log/secure
      maxretry = 5
      bantime = 10m
      findtime = 10m

      [sshd-ddos]
      enabled = true
      port = ssh
      logpath = /var/log/secure
      maxretry = 10
      findtime = 10m
      bantime = 10m
      EOF

        # Enable and start fail2ban
        systemctl enable fail2ban
        systemctl start fail2ban
      fi
  CLOUD
}

resource "hcloud_server" "vps" {
  name         = var.server_name
  image        = var.image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.main.id]
  firewall_ids = [hcloud_firewall.basic.id]
  user_data    = local.cloud_init

  # Ignorar cambios en estos atributos para servidores existentes
  # Estos parámetros solo se usan durante la creación inicial
  # Ignorar image previene recreaciones cuando Hetzner actualiza las imágenes base
  lifecycle {
    ignore_changes = [
      image,
      ssh_keys,
      user_data
    ]
  }
}

# Segundo VPS (x86): tier reutilizable para APIs/BBDD, empezando por Supabase self-hosted.
# Aislado del VPS principal: usuario "deploy" (no-root) con su propia clave
# SSH para la automatización; el root sigue accesible con la clave principal
# solo para acceso manual/de emergencia.
resource "hcloud_server" "vps_apis" {
  name         = var.server2_name
  image        = var.server2_image
  server_type  = var.server2_type
  location     = var.server2_location
  ssh_keys     = [hcloud_ssh_key.main.id, hcloud_ssh_key.apis_deploy.id]
  firewall_ids = [hcloud_firewall.basic.id]
  user_data    = local.cloud_init_apis

  lifecycle {
    ignore_changes = [
      image,
      ssh_keys,
      user_data
    ]
  }
}

# Red privada entre el VPS ARM y el VPS de APIs: el tráfico Traefik -> Kong
# de Supabase (self-hosted) va por aquí, no por internet público. El puerto
# del Kong de Supabase nunca se abre en el firewall público: solo es
# alcanzable desde esta red privada.
resource "hcloud_network" "internal" {
  name     = "codespartan-internal"
  ip_range = "10.0.0.0/24"
}

resource "hcloud_network_subnet" "internal" {
  network_id   = hcloud_network.internal.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}

resource "hcloud_server_network" "vps" {
  server_id  = hcloud_server.vps.id
  network_id = hcloud_network.internal.id
  ip         = "10.0.0.2"
  depends_on = [hcloud_network_subnet.internal]
}

resource "hcloud_server_network" "vps_apis" {
  server_id  = hcloud_server.vps_apis.id
  network_id = hcloud_network.internal.id
  ip         = "10.0.0.3"
  depends_on = [hcloud_network_subnet.internal]
}

# DNS (opcional): crea zonas y A records para subdominios -> IPv4 del VPS
# Si no usas Hetzner DNS (NS del dominio apuntando a Hetzner), comenta todo este bloque.
# Usa los recursos nativos hcloud_zone/hcloud_zone_rrset (Cloud API) en vez del
# antiguo provider timohirt/hetznerdns, retirado junto con dns.hetzner.com.
locals {
  dns_enabled  = length(var.domains) > 0
  aaaa_enabled = var.create_aaaa_records && var.manual_ipv6_address != ""
  public_ipv4  = var.manual_ipv4_address != "" ? var.manual_ipv4_address : hcloud_server.vps.ipv4_address
}

resource "hcloud_zone" "zones" {
  for_each = local.dns_enabled ? toset(var.domains) : []
  name     = each.key
  mode     = "primary"
  ttl      = 300
}

# Subdominios (www, staging, lab por defecto) apuntando al VPS
resource "hcloud_zone_rrset" "subs" {
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

  zone = hcloud_zone.zones[each.value.domain].name
  name = each.value.sub
  type = "A"
  ttl  = 120
  records = [
    { value = local.public_ipv4 },
  ]
}

# AAAA para subdominios (si se habilita y se define IPv6 manual)
resource "hcloud_zone_rrset" "subs_aaaa" {
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

  zone = hcloud_zone.zones[each.value.domain].name
  name = each.value.sub
  type = "AAAA"
  ttl  = 300
  records = [
    { value = var.manual_ipv6_address },
  ]
}

# Apex/root records condicionales
resource "hcloud_zone_rrset" "apex_a" {
  for_each = local.dns_enabled && var.create_apex_a ? toset(var.domains) : []
  zone     = hcloud_zone.zones[each.key].name
  name     = var.apex_name
  type     = "A"
  ttl      = 300
  records = [
    { value = local.public_ipv4 },
  ]
}

resource "hcloud_zone_rrset" "apex_aaaa" {
  for_each = local.dns_enabled && var.create_apex_aaaa && var.manual_ipv6_address != "" ? toset(var.domains) : []
  zone     = hcloud_zone.zones[each.key].name
  name     = var.apex_name
  type     = "AAAA"
  ttl      = 300
  records = [
    { value = var.manual_ipv6_address },
  ]
}

# Registros adicionales (MX/TXT/CNAME/etc.): agrupa por (dominio, name, type)
# porque un RRset admite varios valores bajo el mismo nombre+tipo.
locals {
  additional_flat = flatten([
    for domain, recs in var.dns_additional_records : [
      for r in recs : merge(r, { domain = domain })
    ]
  ])

  additional_grouped = {
    for key, items in {
      for item in local.additional_flat : "${item.domain}_${item.name}_${item.type}" => item...
      } : key => {
      domain = items[0].domain
      name   = items[0].name
      type   = items[0].type
      ttl    = try(items[0].ttl, 300)
      # Hetzner's API requires TXT record values fully wrapped in escaped
      # double quotes (standard DNS zone-file convention); other record
      # types (MX, CNAME...) must stay unquoted.
      records = [
        for it in items : {
          value = it.type == "TXT" ? "\"${replace(it.value, "\"", "\\\"")}\"" : it.value
        }
      ]
    }
  }
}

resource "hcloud_zone_rrset" "additional" {
  for_each = local.dns_enabled ? local.additional_grouped : {}

  zone    = hcloud_zone.zones[each.value.domain].name
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}
