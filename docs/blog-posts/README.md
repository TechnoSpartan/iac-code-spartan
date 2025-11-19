# Blog Posts - CodeSpartan

Carpeta para gestionar posts de blog extraídos de la documentación del proyecto.

## Estructura

```
blog-posts/
├── published/          # Posts publicados o listos para publicar
├── drafts/            # Borradores en progreso
├── ideas/             # Ideas y outlines de posts futuros
└── README.md          # Este archivo
```

## Posts Identificados

### Listos para Publicar (Quick Wins)

1. **El error del firewall que me costó 3 horas: Hetzner Cloud bloquea salida por defecto**
   - Fuente: `docs/07-troubleshooting/FIREWALL_FIX.md`
   - Estado: 📝 Outline en `ideas/`
   - Prioridad: 🔴 Alta
   - Tiempo estimado: 2-3 horas

2. **5 errores que cometí al migrar a Authelia (y cómo los resolví)**
   - Fuente: `docs/05-security/AUTHELIA.md`
   - Estado: 📝 Outline en `ideas/`
   - Prioridad: 🔴 Alta
   - Tiempo estimado: 2-3 horas

### En Desarrollo

3. **Implementé SSO con MFA en 3 horas: Authelia + Traefik paso a paso**
   - Fuente: `docs/05-security/AUTHELIA.md`
   - Estado: 📝 Draft en `drafts/`
   - Prioridad: 🟡 Media
   - Tiempo estimado: 3-4 horas

4. **Disaster Recovery en producción: RTO 15min, RPO 24h con menos de 1€/mes**
   - Fuente: `docs/03-operations/DISASTER_RECOVERY.md`
   - Estado: 📝 Idea en `ideas/`
   - Prioridad: 🟡 Media
   - Tiempo estimado: 3-4 horas

### Ideas para el Futuro

5. **Arquitectura Zero Trust en un VPS: de compartir red a aislamiento completo**
6. **Análisis de mi propia infraestructura: qué hice bien y qué debo mejorar**
7. **Docker Provider vs File Provider: cuándo Traefik no descubre contenedores**
8. **Secret Management: GitHub Secrets vs HashiCorp Vault para proyectos freelance**
9. **Monitoreo completo en ARM64: VictoriaMetrics + Grafana + Loki por menos de 1GB RAM**
10. **Infraestructura como código replicable: un template para múltiples clientes**
11. **Por qué elegí Hetzner Cloud ARM64 para mi infraestructura**

### Serie Completa

12. **Serie: "Construyendo una plataforma Cloud desde cero"** (5-7 partes)
   - Parte 1: Infraestructura con Terraform
   - Parte 2: Reverse Proxy con Traefik
   - Parte 3: Monitoreo completo
   - Parte 4: CI/CD con GitHub Actions
   - Parte 5: Seguridad (Authelia, Fail2ban)
   - Parte 6: Aislamiento y Zero Trust
   - Parte 7: Optimización y escalado

## Formato de Posts

Cada post debe seguir este formato:

```markdown
# Título Atractivo

**Autor:** Jorge Carballo - CodeSpartan  
**Fecha:** YYYY-MM-DD  
**Tiempo de lectura:** X minutos  
**Nivel:** Principiante/Intermedio/Avanzado  
**Tags:** #DevOps #Cloud #Docker #Terraform

## TL;DR
[Resumen ejecutivo con resultados concretos]

## El Problema / Contexto
[Qué problema resuelve, por qué importa]

## La Solución
[Paso a paso con código real]

## Resultados
[Métricas concretas: tiempo ahorrado, costos, etc.]

## Lecciones Aprendidas
[Qué haría diferente, qué evitar]

## Código y Recursos
[Links a repos, scripts, etc.]

## Siguiente Paso
[Qué viene después, cómo profundizar]
```

## Workflow

1. **Idea** → Crear outline en `ideas/`
2. **Draft** → Mover a `drafts/` y desarrollar
3. **Review** → Revisar y mejorar
4. **Published** → Mover a `published/` cuando esté listo

## Referencias

- Post ejemplo existente: `BLOG_POST_CICD.md` (raíz del proyecto)
- Documentación fuente: Ver `docs/README.md` para índice completo

