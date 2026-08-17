# Cómo debuggeé y arreglé un flujo de auth fallido en 1.5 horas (full-stack)

**Autor:** Jorge Carballo · CodeSpartan  
**Fecha:** Enero 2026  
**Tags:** `#debugging`, `#auth`, `#microservices`, `#security`, `#trackworks`

---

## TL;DR

**Problema:** Login exitoso → llamadas a API protegidas devuelven `401 Unauthorized`.  
**Causa raíz:** Tokens generados no se registraban en lista de válidos del middleware.  
**Fix:** Auto-registro de tokens + simplificación de formato + 5 tests de validación.  
**Resultado:** Flujo Frontend → BFF → Mock-Server funcionando. **0 bugs pendientes**.  
**Tiempo total:** 1.5 horas (incluyendo documentación completa).

---

## El dolor: login funciona, pero la app no

TrackWorks es una arquitectura **Frontend → BFF → Mock-Server** (por ahora). El flujo debería ser:

```bash
Usuario → Login → Token → localStorage → API Calls → 200 OK
```

Lo que pasaba:

```bash
Usuario → Login → Token → localStorage → API Calls → 401 Unauthorized ❌
```

Síntoma:

```bash
Error: GET http://localhost:4200/api/v1/workorders?_offset=0&_limit=100 401 (Unauthorized)
```

**Primera intuición**: Problema de tokens. Pero ¿dónde exactamente?

### Debugging sistemático: dónde estaba el problema

**Paso 1**: Verificar frontend (5 min)

- `authService.ts` ✅ Guarda token en localStorage
- `AuthContext.tsx`  ✅ Añade  `Authorization: Bearer`  en headers
- DevTools Network ✅ Headers correctos

**Paso 2**: Verificar BFF (3 min)

- **routes/workorders.ts** ✅ Reenvía `Authorization` al backend

*Paso 3*: Ir al Mock-Server (crítico)

- `routes/auth.js` ❌ Token generado con formato Base64 complejo
- `middleware/auth.js` ✅ Lista de tokens válidos estática
- **Causa raíz:** Token generado **NO se agregaba** a la lista de válidos

**Lección**: El 80% de los 401 “después de login exitoso” están en el backend.

## El fix: simple, pero con intención arquitectónica

### Antes: tokens complejos sin auto-registro

```javascript
// ❌ GENERACIÓN ANTES
function generateMockToken(user) {
  const mockToken = Buffer.from(JSON.stringify({ userId: user.id, role: user.role })).toString('base64');
  return { accessToken: `Bearer ${mockToken}` }; // ← No registrado
}
```

### Después: tokens simples + auto-registro

```javascript
// ✅ GENERACIÓN DESPUÉS
import { addValidToken } from '../middleware/auth.js';

function generateMockToken(user) {
  const token = `mock-token-${user.id}-${user.role}-${Date.now()}`;
  
  // 🔥 CRÍTICO: Auto-registro
  addValidToken(token);
  
  return {
    accessToken: token, // Cliente añade "Bearer "
    refreshToken: `refresh-${token}`,
    expiresIn: 3600,
  };
}
```

### Por qué este formato de token?

- Legible:  **mock-token-user-mgr-001-manager-1767177692131**
- Debuggeable: Sin decodificar Base64
- Información útil: userId, role, timestamp en claro
- Simple: Fácil de parsear en middleware

### Tests de validación: no solo arreglar, verificar

No basta con que funcione en tu máquina. Hay que probar todos los casos:

| Test | Estado | Resultado |
|------|--------|-----------|
| Health Check | ✅ PASS | 200 OK |
| Login + Token | ✅ PASS | Token válido generado |
| Access Protected Endpoint | ✅ PASS | 200 OK + Datos |
| Access Without Token | ✅ PASS | 401 Unauthorized |
| Access Invalid Token | ✅ PASS | 401 Unauthorized |

5/5 tests pasando. Seguridad validada.

## Bonus fixes encontrados durante el debugging

### 1. WO-UNKNOWN en detalle de Work Order

**Bug**: Header mostraba `workOrder.id`(12345) en lugar de `workOrder.woNumber` (WO-2025-0001).

#### Fix (1 línea)

```diff
// WorkOrderDetailPage.tsx
- <h1>{workOrder.id}</h1>
+ <h1>{workOrder.woNumber}</h1>
```

### 2. Endpoint `/health` para monitoring

```javascript
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
  });
});
```

## Deuda técnica identificada: RBAC middleware

Encontramos un hueco arquitectónico: **permisos por rol** no implementados.
**Faltan:**

- `ProtectedRoute` middleware
- `PermissionGate` para acciones granulares
- Audit logging de accesos denegados

**Plan:** 2-3 días de implementación. Documentado en Technical Debt con arquitectura detallada.
**Lección:** Debugging → no solo arreglar el bug, sino mejorar la arquitectura detectada.

## Resultados: commits y estado final

Commits realizados

```bash
1. fix(mock-server): add /health endpoint and fix auth token generation
   - Auto-register generated tokens in valid list
   - Simplified token format for easier debugging

2. fix(work-orders): display correct WO number in detail page
   - Changed workOrder.id → workOrder.woNumber

3. docs: comprehensive auth flow debugging case study
   - Full analysis + diagrams + validation tests
```

Estado: ✅ Auth flow completamente funcional. Listo para nuevos dominios.

## Lecciones de arquitectura para tu próximo 401

- **Debuggea por capas**: Frontend → BFF → Backend. No asumas.
- **Tokens deben auto-registrarse**. Generar ≠ validar.
- **Formato simple para debugging**: Evita Base64 hasta producción.
- **Siempre valida seguridad**: Sin token, token inválido, token expirado.
- **Documenta mientras arreglas**. 30min extra = caso de estudio portfolio-worthy.

**Tiempo total**: 1.5h (fix + docs + tests).

**ROI**: Sistema robusto + contenido reutilizable.

Piensa. Crea. Escala. ⚔️

¿Quieres el breakdown completo con diagramas? [DM](mailto:jcarballo@codespartan.es).
[CodeSpartan.es](https://www.codespartan.es) | Arquitecto JS/TS
