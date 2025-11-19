# Pre-requisitos

Lista de requisitos previos necesarios para desplegar la plataforma.

## Cuentas y Servicios

- [ ] **Hetzner Cloud**: Cuenta activa con acceso a API
- [ ] **Hetzner DNS**: Cuenta activa con acceso a API (puede ser diferente a Cloud)
- [ ] **GitHub**: Repositorio con acceso a GitHub Actions
- [ ] **Dominio**: Dominio propio con acceso a configuración DNS

## Tokens y Credenciales

### Hetzner Cloud Token

1. Ve a: https://console.hetzner.cloud
2. Security → API tokens
3. Genera nuevo token con permisos de lectura/escritura
4. Guarda el token (solo se muestra una vez)

### Hetzner DNS Token

1. Ve a: https://dns.hetzner.com
2. Settings → API tokens
3. Genera nuevo token
4. Guarda el token

### SSH Key

```bash
# Generar nueva clave SSH
ssh-keygen -t ed25519 -f ~/.ssh/id_codespartan -C "codespartan@mambo-cloud.com"

# Ver clave pública (para Terraform)
cat ~/.ssh/id_codespartan.pub

# Ver clave privada (para GitHub Secrets)
cat ~/.ssh/id_codespartan
```

## Configuración DNS

### Nameservers

Tu dominio debe tener los nameservers de Hetzner:

```
helium.ns.hetzner.de
hydrogen.ns.hetzner.de
oxygen.ns.hetzner.de
```

### Verificación

```bash
# Verificar nameservers
dig NS tu-dominio.com

# Debe mostrar los nameservers de Hetzner
```

## Conocimientos Recomendados

- Conocimiento básico de Docker
- Familiaridad con GitHub Actions
- Conceptos básicos de DNS
- Uso básico de terminal/SSH

## Herramientas Locales (Opcional)

- `terraform` - Para ejecutar Terraform localmente
- `docker` - Para probar contenedores localmente
- `git` - Para gestionar el repositorio

## Recursos del VPS

El VPS mínimo recomendado (cax11 en Hetzner):
- 2 vCPU
- 4GB RAM
- 40GB SSD
- ARM64 architecture

## Siguiente Paso

Una vez completados los pre-requisitos, sigue la [Guía de Despliegue Rápido](QUICK_START.md).

