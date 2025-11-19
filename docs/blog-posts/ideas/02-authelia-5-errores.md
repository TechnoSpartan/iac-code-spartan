# 5 Errores que Cometí al Migrar a Authelia (y Cómo los Resolví)

**Estado:** 📝 Idea / Outline  
**Prioridad:** 🔴 Alta  
**Tiempo estimado:** 2-3 horas  
**Fuente:** `docs/05-security/AUTHELIA.md` (sección "Problemas Encontrados")

---

## Estructura del Post

### TL;DR
Implementé Authelia SSO con MFA en 3 horas, pero cometí 5 errores que me costaron tiempo extra. Aquí están y cómo los resolví.

### Error 1: Password Hash Incorrecto
**Problema:** Login fallaba con credenciales correctas  
**Causa:** Hash generado localmente no coincidía  
**Solución:** Generar hash en el mismo entorno donde se usa  
**Código:** Workflow de generación automática

### Error 2: Gateway Timeout por Configuración Inválida
**Problema:** HTTP 504 después de recrear contenedor  
**Causa:** Configuración inválida (`elevated_session` no existe)  
**Solución:** Validar configuración antes de desplegar  
**Lección:** Siempre verificar versión de Authelia y keys disponibles

### Error 3: Conflicto SMTP vs Filesystem Notifier
**Problema:** Authelia crasheaba con ambos notifiers  
**Causa:** Authelia NO permite tener ambos simultáneamente  
**Solución:** Elegir uno (filesystem para desarrollo, SMTP para producción)  
**Lección:** Leer documentación completa antes de configurar

### Error 4: Sesiones sin Persistencia
**Problema:** Sesiones se perdían al reiniciar contenedor  
**Causa:** No configuré Redis para sesiones  
**Solución:** Agregar Redis como session store  
**Lección:** Sesiones en memoria no son suficientes para producción

### Error 5: Políticas de Acceso Incorrectas
**Problema:** Usuarios no podían acceder a servicios protegidos  
**Causa:** Reglas de access control demasiado restrictivas  
**Solución:** Configurar políticas por dominio y grupo correctamente  
**Lección:** Probar políticas incrementalmente

### Lecciones Generales
- Siempre generar hashes en el entorno de producción
- Validar configuración antes de desplegar
- Leer documentación completa (no solo ejemplos)
- Usar Redis para sesiones en producción
- Probar políticas de acceso incrementalmente

---

## Puntos Clave

- **Errores reales** que otros pueden evitar
- **Soluciones concretas** con código
- **Lecciones aplicables** a otros proyectos
- **Tono honesto** (mostrar errores es valioso)

## Target Audience

- DevOps engineers implementando SSO
- Desarrolladores que usan Authelia
- Personas que quieren evitar errores comunes

