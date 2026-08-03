# Valores específicos para la plataforma (mambo-cloud.com)

server_name = "CodeSpartan-alma"
image       = "alma-9"
server_type = "cax11"
location    = "nbg1"

# Segundo VPS (x86): tier reutilizable para APIs/BBDD (empieza con Supabase self-hosted)
server2_name     = "CodeSpartan-apis"
server2_type     = "cx33"
server2_image    = "alma-9"
server2_location = "nbg1"

ssh_key_name = "codespartan"
# SSH key content viene de GitHub Secret: TF_VAR_ssh_public_key_content
# Para uso local, descomenta la línea siguiente y añade tu clave pública:
# ssh_public_key_content = "ssh-ed25519 AAAA... tu-clave-publica"

# SSH abierto a todos por ahora (restringe cuando tengas tu IP fija)
firewall_allowed_ssh_cidrs = ["0.0.0.0/0", "::/0"]

# DNS (Hetzner DNS)
# Nota: codespartan.es (www en Hostinger/WordPress) no se gestiona aquí.
domains    = ["mambo-cloud.com", "cyberdyne-systems.es", "codespartan.cloud", "dental-ia.es"]
subdomains = ["traefik", "grafana", "backoffice", "www", "staging", "lab", "lab-staging", "api", "api-staging", "project", "ui", "mambo", "portainer", "crm", "auth"]

# IPv4/IPv6 concretos para los registros A/AAAA
manual_ipv4_address = "91.98.137.217"
create_aaaa_records = true
# IPv6 correcta proporcionada por el usuario
manual_ipv6_address = "2a01:4f8:1c1a:7d21::1"

# Apex/root del dominio (ambos activados para cyberdyne-systems.es)
create_apex_a    = true
create_apex_aaaa = true
apex_name        = "@"

# Nota: la verificación de dominio Brevo para envío de campañas se hizo sobre
# codespartan.es (no codespartan.cloud), y ese dominio vive en Hostinger/WordPress,
# fuera del alcance de este Terraform. Los registros (TXT brevo-code, 2x CNAME
# DKIM, TXT _dmarc) se añaden manualmente en el panel DNS de Hostinger.
#
# DNS adicionales para codespartan.cloud (gestionado en Hetzner):
#   - ImprovMX: forwarding gratuito para recibir emails (verificación Brevo)
#   - Brevo mail.codespartan.cloud: subdominio de envío de campañas (PLACEHOLDERS)
#     Sustituir OBTENER_DE_BREVO_DASHBOARD por valores reales del dashboard Brevo.
dns_additional_records = {
  "codespartan.cloud" = [
    # ImprovMX — forwarding gratuito
    { name = "@", type = "MX", value = "10 mx1.improvmx.com.", ttl = 300 },
    { name = "@", type = "MX", value = "20 mx2.improvmx.com.", ttl = 300 },
    { name = "@", type = "TXT", value = "v=spf1 include:spf.improvmx.com ~all" },
    # Brevo — verificación del dominio apex codespartan.cloud
    { name = "@", type = "TXT", value = "brevo-code:c7e0b4779e7e17ee0c0bf8c0e5decf0a" },
    # Brevo — DKIM (CNAME)
    { name = "brevo1._domainkey", type = "CNAME", value = "b1.codespartan-cloud.dkim.brevo.com." },
    { name = "brevo2._domainkey", type = "CNAME", value = "b2.codespartan-cloud.dkim.brevo.com." },
    # Brevo — DMARC apex
    { name = "_dmarc", type = "TXT", value = "v=DMARC1; p=none; rua=mailto:rua@dmarc.brevo.com" },

    # Brevo — subdominio mail.codespartan.cloud (envío de campañas)
    { name = "mail", type = "TXT", value = "v=spf1 include:spf.brevo.com ~all" },
  ]
}
