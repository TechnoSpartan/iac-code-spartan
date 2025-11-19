# Documentación CodeSpartan Mambo Cloud Platform

Índice principal de toda la documentación del proyecto.

## Quick Start

Para nuevos usuarios que quieren empezar rápidamente:

- [Guía para Principiantes](01-getting-started/BEGINNER.md) - Tutorial paso a paso para principiantes
- [Quick Start](01-getting-started/QUICK_START.md) - Despliegue rápido en 5 pasos
- [Pre-requisitos](01-getting-started/PREREQUISITES.md) - Requisitos previos necesarios

## Arquitectura

Documentación sobre el diseño y arquitectura de la plataforma:

- [Arquitectura Completa](02-architecture/ARCHITECTURE.md) - Arquitectura Zero Trust con diagramas
- [Análisis Arquitectónico](02-architecture/ANALISIS_ARQUITECTURA.md) - Análisis completo de calidad y mejoras
- [System Overview](02-architecture/OVERVIEW.md) - Visión general del sistema
- [Networking](02-architecture/NETWORKING.md) - Redes y conectividad
- [Recursos y Límites](02-architecture/RESOURCES.md) - Gestión de recursos del VPS
- [Diagramas Mermaid](02-architecture/mermaid.md) - Diagramas de arquitectura

## Operaciones

Guías para operaciones diarias y mantenimiento:

- [Runbook Operativo](03-operations/RUNBOOK.md) - Guía operativa completa día a día
- [Gestión de Aplicaciones](03-operations/APPLICATIONS.md) - Cómo gestionar aplicaciones desplegadas
- [Monitoreo y Alertas](03-operations/MONITORING.md) - Sistema de monitoreo y alertas
- [Backups](03-operations/BACKUPS.md) - Operaciones de backup diarias
- [Disaster Recovery Plan](03-operations/DISASTER_RECOVERY.md) - Plan completo de recuperación ante desastres

## Despliegue

Documentación sobre despliegue y CI/CD:

- [Guía de Despliegue](04-deployment/DEPLOYMENT.md) - Guía completa de despliegue inicial
- [Añadir Aplicaciones](04-deployment/ADDING_APPS.md) - Cómo añadir nuevas aplicaciones
- [CI/CD con GitHub Actions](04-deployment/GITHUB.md) - Configuración y uso de GitHub Actions
- [Terraform](04-deployment/TERRAFORM.md) - Gestión de infraestructura con Terraform
- [OpenProject Deployment](04-deployment/OPENPROJECT_DEPLOYMENT.md) - Resumen despliegue OpenProject
- [Roadmap Cyberdyne](04-deployment/ROADMAP_CYBERDYNE.md) - Roadmap específico Cyberdyne Systems

## Seguridad

Documentación sobre seguridad y hardening:

- [Gestión de Secretos](05-security/SECRET_MANAGEMENT.md) - Cómo gestionar secretos de forma segura
- [Fail2ban](05-security/FAIL2BAN.md) - Protección SSH contra ataques de fuerza bruta
- [Authelia SSO](05-security/AUTHELIA.md) - Single Sign-On con Multi-Factor Authentication
- [Security Hardening](05-security/HARDENING.md) - Mejores prácticas de seguridad

## Implementación

Planes de implementación y fases del proyecto:

- [Plan de Implementación](06-implementation/IMPLEMENTATION_PLAN.md) - Plan general de implementación Zero Trust (incluye Fases 1-5)
- [Roadmap](06-implementation/ROADMAP.md) - Roadmap completo del proyecto
- [Plan de Mejoras](06-implementation/IMPROVEMENT_PLAN.md) - Roadmap de mejoras futuras

## Troubleshooting

Guías para resolver problemas comunes:

- [Índice de Troubleshooting](07-troubleshooting/INDEX.md) - Índice de problemas y soluciones
- [Problemas con Traefik](07-troubleshooting/TRAEFIK.md) - Troubleshooting específico de Traefik
- [Problemas DNS](07-troubleshooting/DNS.md) - Resolución de problemas DNS
- [Problemas SSL](07-troubleshooting/SSL.md) - Problemas con certificados SSL
- [Problemas Comunes](07-troubleshooting/COMMON_ISSUES.md) - Problemas frecuentes y soluciones
- [Firewall Fix](07-troubleshooting/FIREWALL_FIX.md) - Solución problema firewall Hetzner
- [VPS Migration](07-troubleshooting/VPS_MIGRATION.md) - Plan de migración de VPS
- [VPS Network](07-troubleshooting/VPS_NETWORK.md) - Troubleshooting de red VPS
- [VPS Recovery](07-troubleshooting/VPS_RECOVERY.md) - Estado de recuperación VPS

## Referencia

Documentación de referencia técnica:

- [Sistema de Alertas](08-reference/ALERTS.md) - Configuración y uso del sistema de alertas
- [APIs y Endpoints](08-reference/API.md) - Documentación de APIs disponibles
- [Comandos Útiles](08-reference/COMMANDS.md) - Comandos de referencia rápida

## Blog Posts

Contenido extraído de la documentación para publicación en blog:

- [Índice de Posts](blog-posts/README.md) - Lista completa de posts identificados
- [Ideas](blog-posts/ideas/) - Outlines y estructuras de posts futuros
- [Borradores](blog-posts/drafts/) - Posts en desarrollo
- [Publicados](blog-posts/published/) - Posts listos o publicados

---

## Estructura de Carpetas

```
docs/
├── 01-getting-started/     # Documentación para nuevos usuarios
├── 02-architecture/        # Arquitectura y diseño
├── 03-operations/          # Operaciones diarias
├── 04-deployment/          # Despliegue y CI/CD
├── 05-security/            # Seguridad
├── 06-implementation/      # Planes de implementación
├── 07-troubleshooting/     # Resolución de problemas
└── 08-reference/           # Referencia técnica
```

## Contribuir a la Documentación

Al añadir nueva documentación:

1. Coloca el archivo en la carpeta correspondiente según su categoría
2. Actualiza este README.md con el enlace
3. Mantén consistencia en el formato (Markdown)
4. Incluye ejemplos prácticos cuando sea posible

---

**Última actualización**: 2025-11-18
**Mantenido por**: CodeSpartan Team
