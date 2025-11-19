# Security Hardening

Mejores prácticas de seguridad implementadas en la plataforma.

## Medidas de Seguridad Implementadas

### Firewall

- Hetzner Cloud Firewall configurado
- Solo puertos 22 (SSH), 80 (HTTP), 443 (HTTPS) abiertos
- Reglas de salida para tráfico esencial

### SSL/TLS

- Certificados automáticos con Let's Encrypt
- Renovación automática de certificados
- HTTPS forzado para todos los servicios

### Autenticación

- Authelia SSO con MFA para dashboards
- Basic Auth en servicios de gestión
- Fail2ban para protección SSH (pendiente de implementar)

### Rate Limiting

- Rate limiting global en Traefik
- Protección contra DDoS básica
- Límites por IP configurados

## Mejoras Pendientes

### Prioridad Alta

- [ ] docker-socket-proxy (eliminar acceso directo de Traefik al socket)
- [ ] Fail2ban implementado y funcionando
- [ ] Secret management (migrar a GitHub Secrets)
- [ ] Aislamiento completo de redes por aplicación

### Prioridad Media

- [ ] Kong API Gateway por dominio
- [ ] Security headers mejorados
- [ ] Audit logging centralizado
- [ ] Security scanning automatizado

## Documentación Relacionada

- [Fail2ban](FAIL2BAN.md) - Protección SSH
- [Authelia SSO](AUTHELIA.md) - Autenticación centralizada
- [Secret Management](SECRET_MANAGEMENT.md) - Gestión de secretos
- [Arquitectura](../02-architecture/ARCHITECTURE.md) - Roadmap de seguridad

