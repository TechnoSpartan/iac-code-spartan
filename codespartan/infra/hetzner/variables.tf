variable "hcloud_token" {
  description = "Hetzner Cloud API token (puede venir por env HCLOUD_TOKEN)."
  type        = string
  default     = ""
}

variable "hetzner_dns_token" {
  description = "Hetzner DNS API token (para provider hetznerdns)."
  type        = string
  default     = ""
}

variable "server_name" {
  description = "Nombre del servidor VPS."
  type        = string
  default     = "codespartan-vps"
}

variable "image" {
  description = "Imagen del sistema. Ej: alma-9"
  type        = string
  default     = "alma-9"
}

variable "server_type" {
  description = "Tipo de servidor (ARM: cax11, cax21, ...)."
  type        = string
  default     = "cax11"
}

variable "location" {
  description = "Ubicación: nbg1, fsn1, hel1"
  type        = string
  default     = "nbg1"
}

variable "ssh_key_name" {
  description = "Nombre del recurso de clave SSH en Hetzner."
  type        = string
  default     = "codespartan"
}

variable "ssh_public_key_path" {
  description = "Ruta a la clave pública para provisionar el acceso SSH."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "firewall_allowed_ssh_cidrs" {
  description = "CIDRs permitidos para SSH (22/tcp). Recomendado restringir a tu IP."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "domains" {
  description = "Lista de dominios a gestionar en Hetzner DNS (si usas sus NS)."
  type        = list(string)
  default     = []
}

variable "subdomains" {
  description = "Subdominios a crear como A records apuntando al VPS."
  type        = list(string)
  default     = ["www", "staging", "lab"]
}

variable "dns_additional_records" {
  description = "Mapa dominio => lista de registros adicionales { name, type, value, ttl? } (MX/TXT/CNAME/etc.)."
  type = map(list(object({
    name  = string
    type  = string
    value = string
    ttl   = optional(number)
  })))
  default = {}
}

variable "create_aaaa_records" {
  description = "Si true y manual_ipv6_address no vacío, crea AAAA para subdominios."
  type        = bool
  default     = false
}

variable "manual_ipv6_address" {
  description = "IPv6 del VPS para registros AAAA (rellena manualmente si quieres AAAA)."
  type        = string
  default     = ""
}

variable "create_apex_a" {
  description = "Crear registro A para el apex/root (@) de cada dominio apuntando al VPS."
  type        = bool
  default     = false
}

variable "create_apex_aaaa" {
  description = "Crear registro AAAA para el apex/root (@) de cada dominio apuntando al IPv6 indicado."
  type        = bool
  default     = false
}

variable "apex_name" {
  description = "Nombre para el apex/root en el provider hetznerdns. Suele ser '@' o vacio ''."
  type        = string
  default     = "@"
}

variable "manual_ipv4_address" {
  description = "IPv4 a usar en registros A (si se define, tiene prioridad sobre la IPv4 del VPS)."
  type        = string
  default     = ""
}
