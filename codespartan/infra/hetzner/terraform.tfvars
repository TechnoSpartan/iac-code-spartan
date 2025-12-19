# Valores específicos para la plataforma (mambo-cloud.com)

server_name = "CodeSpartan-alma"
image       = "alma-9"
server_type = "cax11"
location    = "nbg1"

ssh_key_name = "codespartan"
# SSH key content viene de GitHub Secret: TF_VAR_ssh_public_key_content
# Para uso local, descomenta la línea siguiente y añade tu clave pública:
# ssh_public_key_content = "ssh-ed25519 AAAA... tu-clave-publica"

# SSH abierto a todos por ahora (restringe cuando tengas tu IP fija)
firewall_allowed_ssh_cidrs = ["0.0.0.0/0", "::/0"]

# DNS (Hetzner DNS)
# Nota: codespartan.es (www en Hostinger/WordPress) no se gestiona aquí.
domains    = ["mambo-cloud.com", "cyberdyne-systems.es", "codespartan.cloud"]
subdomains = ["traefik", "grafana", "backoffice", "www", "staging", "lab", "lab-staging", "api", "api-staging", "project", "ui", "mambo", "portainer"]

# IPv4/IPv6 concretos para los registros A/AAAA
manual_ipv4_address = "91.98.137.217"
create_aaaa_records = true
# IPv6 correcta proporcionada por el usuario
manual_ipv6_address = "2a01:4f8:1c1a:7d21::1"

# Apex/root del dominio (ambos activados para cyberdyne-systems.es)
create_apex_a    = true
create_apex_aaaa = true
apex_name        = "@"
