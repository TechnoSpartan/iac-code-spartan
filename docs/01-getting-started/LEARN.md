Guía de Aprendizaje - Codespartan (Hetzner + Traefik + IaC)

Objetivo
- Entender la arquitectura, las decisiones técnicas y el proceso end-to-end para desplegar dominios y apps en un VPS ARM de Hetzner, con DNS gestionado como código, reverse proxy, SSL, observabilidad y backups.

Arquitectura (visión general)
- Infraestructura (Terraform)
  - Hetzner Cloud: 1 VPS ARM (p. ej. cax11) con firewall (22/80/443 e ICMP opcional).
  - Hetzner DNS: zonas y registros (A/AAAA para subdominios, apex opcional, y registros adicionales: MX, TXT/SPF, DKIM, etc.).
  - Nota apex: según provider/versión, el nombre del apex puede ser "@" o cadena vacía ''. En este repo está parametrizado via variable apex_name.
- Plataforma
  - Traefik: reverse proxy único para múltiples dominios/subdominios; HTTPS automático (Let's Encrypt HTTP-01); red docker externa "web".
  - Redirección HTTP→HTTPS. Dashboard con Basic Auth. Métricas Prometheus expuestas.
- Apps
  - Una app = un stack docker-compose con labels Traefik para Host() (www, staging, lab), unido a la red "web".
- Observabilidad
  - Logs: Loki + Promtail (ligero y suficiente para 1 VPS ARM) 
  - Métricas: Prometheus, cAdvisor, node-exporter; visualización con Grafana; Alertmanager para alertas (email/Slack opcional).
- Backups
  - Restic a S3/B2 (o compatible), con política de retención configurable.
- Backoffice
  - Nginx estático protegido por Basic Auth para un mini portal interno.

Decisiones clave (por qué así)
- Un solo Traefik: simplifica puertos, certificados y gestión multi-dominio.
- Hetzner DNS + Terraform: DNS como código (dominios y subdominios reproducibles).
- Let's Encrypt HTTP-01: menos fricción (solo requiere 80/443 abiertos y DNS resuelto).
- Loki/Promtail vs ELK: menor consumo en ARM, suficiente para observabilidad básica.
- Prometheus/Grafana/Alertmanager: estándar de facto, extensible con dashboards y reglas.

Flujo IaC (Terraform)
1) Providers: Hetzner Cloud (VPS/firewall) y Hetzner DNS (zonas/records).
2) Variables:
   - domains, subdomains: control de qué dominios y subdominios crear.
   - dns_additional_records: lista por dominio de MX/TXT/DKIM/CNAME (usa exactamente valores de tu proveedor de correo).
   - IPv6: create_aaaa_records + manual_ipv6_address para crear AAAA.
   - Apex: create_apex_a, create_apex_aaaa y apex_name.
3) Outputs: IPv4 y zona IDs (para referencia).
4) Pitfalls comunes:
   - Propagación DNS: espera unos minutos tras aplicar.
   - Apex name: si "@" falla, usa "" (vacío) y reaplica.

Flujo CI/CD (GitHub Actions)
- Workflows por stack: infra (Terraform), Traefik, apps, monitoring, logging, backups, backoffice.
- Secretos: cada workflow lee los suyos (ver docs/GITHUB.md).
- Patrón de despliegue: copiar archivos al VPS con SCP y ejecutar docker compose.

Secuencia recomendada de despliegue
1) Terraform (infra + DNS)
   - Define dominios/subdominios; activa AAAA y apex si quieres.
   - Aplica y espera propagación.
2) Traefik
   - Define secretos (ACME, dashboard host y Basic Auth).
   - Despliega y verifica el dashboard por HTTPS.
3) Observabilidad
   - Logging (Loki + Promtail) primero, luego Monitoring (Prometheus + Grafana).
   - Define GRAFANA_HOST y (opcional) alertas por email/Slack.
4) Apps
   - Para cada app, define BASE_DOMAIN y despliega.
5) Backups y Backoffice (opcionales)
   - Configura repositorio Restic y credenciales.
   - Publica Backoffice con Basic Auth.

Cómo añadir un nuevo dominio
1) Añade el dominio a "domains" en terraform.tfvars y subdominios deseados en "subdomains".
2) (Opcional) apex A/AAAA: activa create_apex_a/create_apex_aaaa y apex_name si procede.
3) Aplica Terraform y espera propagación.
4) Añade un stack de app a codespartan/apps/<nombre> con labels Traefik para ese dominio.
5) Crea/ajusta su workflow de deploy.

Cómo añadir una nueva app
1) Crea docker-compose.yml con labels Traefik (routers por subdominio) y red "web".
2) Añade .env.example con BASE_DOMAIN.
3) Crea el workflow de deploy copiando uno existente y ajustando rutas.
4) Si usas nuevos subdominios, añádelos en Terraform.

Cómo añadir dashboards en Grafana
- Coloca JSONs en codespartan/platform/stacks/monitoring/grafana/dashboards/
- Asegúrate que están listados por el provisioning (ya apunta a esa ruta).
- Redeploy de Monitoring para que Grafana los recoja (o Import manual desde la UI).

Cómo añadir reglas/alertas en Prometheus
- Añade archivos .yml en codespartan/platform/stacks/monitoring/prometheus/rules/
- Redeploy de Monitoring.
- Verifica en Prometheus → Status → Rules y en Alertmanager.

IPv6 / AAAA
- Activa create_aaaa_records y especifica manual_ipv6_address.
- (Opcional) crea apex AAAA con create_apex_aaaa.
- Verifica con dig o curl -6 que el acceso funciona y que LE emite certificados (Traefik maneja A/AAAA sin cambios).

Seguridad básica
- SSH: restringe firewall_allowed_ssh_cidrs a tu IP.
- Traefik dashboard/Backoffice: usa Basic Auth con bcrypt robusto.
- Certificados: acme.json con permisos 600.
- Actualizaciones: dnf upgrade -y periódicamente.

Troubleshooting
- Let’s Encrypt no emite cert:
  - DNS no resuelve a la IP del VPS → espera propagación o corrige registros.
  - Puerto 80/443 bloqueados → revisa firewall de Hetzner y que Traefik está escuchando.
- Traefik devuelve 404:
  - FQDN no coincide con la regla Host() → revisa labels.
  - Servicio no unido a la red "web" → añade networks: [web].
- Prometheus → targets DOWN:
  - Containers no levantados o sin red → docker ps / networks.
  - Nombre/puerto objetivo mal → corrige en prometheus.yml.
- Loki sin logs en Grafana:
  - Promtail sin permisos a /var/lib/docker/containers → revisa montaje.
  - Filtros de consulta en Grafana → usa "{job=\"docker\"}" y amplia rango temporal.
- Actions falla en SCP/SSH:
  - VPS_SSH_KEY formateado mal o sin permisos → vuelve a pegar en Secrets.

Comandos útiles (local)
```zsh
# Terraform
terraform -chdir=codespartan/infra/hetzner init
HCLOUD_TOKEN=$HCLOUD_TOKEN terraform -chdir=codespartan/infra/hetzner plan -var "hetzner_dns_token=$HETZNER_DNS_TOKEN"
HCLOUD_TOKEN=$HCLOUD_TOKEN terraform -chdir=codespartan/infra/hetzner apply -var "hetzner_dns_token=$HETZNER_DNS_TOKEN"

# DNS checks
dig +short A www.tu-dominio.es
dig +short AAAA www.tu-dominio.es

# Cert check (traefik dashboard)
curl -I https://traefik.tu-dominio.es

# Grafana acceso
open https://grafana.tu-dominio.es
```

Siguientes pasos
- Personaliza dashboards y alertas a tus métricas de negocio.
- Añade healthchecks y canary deploys si crece la plataforma.
- Evalúa backups específicos de datos de apps (volúmenes o bases de datos) además de /opt/codespartan.

Con esta guía deberías poder entender el porqué de cada componente y ejecutar el ciclo completo desde cero con confianza. ¡A por ello!

