# 🔐 RBAC Middleware Implementation - Deuda Técnica

**Fecha de Creación:** 2025-12-31  
**Prioridad:** 🔴 **ALTA** (Fundamento para todos los dominios)  
**Estimación:** 2-3 días  
**Complejidad:** Media-Alta  
**Beneficio:** 🔥🔥🔥 (Seguridad + Escalabilidad)

---

## 📋 Descripción del Problema

### Situación Actual

Actualmente, el control de acceso basado en roles (RBAC) está **parcialmente implementado**:

#### ✅ Lo que ya existe:

1. **Tipos de permisos definidos** (`apps/web/src/domains/auth/types/permission.types.ts`)
   ```typescript
   export enum Module {
     DASHBOARD = 'dashboard',
     WORK_ORDERS = 'work_orders',
     TECH_TOOLS = 'tech_tools',
     EQUIPMENT = 'equipment',
     INVENTORY = 'inventory',
     PM_SCHEDULER = 'pm_scheduler',
     ESTIMATES = 'estimates',
     PURCHASE_ORDERS = 'purchase_orders',
     MESSAGES = 'messages',
     SCHEDULER_TIME = 'scheduler_time',
     SERVICE = 'service',
   }

   export enum PermissionAction {
     VIEW = 'view',
     CREATE = 'create',
     EDIT = 'edit',
     DELETE = 'delete',
     APPROVE = 'approve',
   }
   ```

2. **Hook de permisos** (`apps/web/src/domains/auth/hooks/usePermissions.ts`)
   ```typescript
   export const usePermissions = () => {
     const { user } = useAuth();
     
     const can = (module: Module, action: PermissionAction): boolean => {
       // Implementación básica
     };
     
     const hasFullPermission = (module: Module, action: PermissionAction): boolean => {
       // Implementación básica
     };
     
     return { can, hasFullPermission, getScope };
   };
   ```

3. **Matriz de roles** (`docs/ROLES_AND_DOMAINS_COMPLETE_MATRIX.md`)
   - 8 roles definidos
   - 23 dominios identificados
   - Permisos mapeados por rol y dominio

#### ❌ Lo que falta:

1. **Middleware de protección de rutas**
   - No hay HOC o componente que valide permisos antes de renderizar
   - Las páginas se cargan y luego validan permisos inline (inseguro)

2. **Protección granular por acción**
   - No hay un sistema centralizado para validar permisos en acciones (botones, formularios)
   - Cada componente valida permisos de forma ad-hoc

3. **Feedback visual consistente**
   - No hay un componente estándar para mostrar "Sin permisos" o "Acceso denegado"
   - Cada página implementa su propia UI de error

4. **Audit logging de accesos denegados**
   - No se registran intentos de acceso no autorizados
   - Sin trazabilidad de intentos de escalada de privilegios

5. **Tests de permisos**
   - No hay tests unitarios para validar RBAC
   - No hay tests E2E para verificar restricciones

---

## 🎯 Objetivos de la Implementación

### 1️⃣ Middleware de Protección de Rutas

**Objetivo:** Validar permisos antes de renderizar cualquier ruta protegida.

**Componentes a crear:**

#### `ProtectedRoute` Component

```typescript
// apps/web/src/shared/components/ProtectedRoute.tsx
interface ProtectedRouteProps {
  module: Module;
  action?: PermissionAction;
  scope?: 'all' | 'own';
  fallback?: React.ReactNode;
  children: React.ReactNode;
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  module,
  action = PermissionAction.VIEW,
  scope,
  fallback,
  children,
}) => {
  const { can, getScope } = usePermissions();
  const navigate = useNavigate();

  // Validar permisos
  if (!can(module, action)) {
    // Redirigir a página de "Sin permisos"
    return <UnauthorizedPage module={module} action={action} />;
  }

  // Validar scope si se especifica
  if (scope && getScope(module, action) !== scope && getScope(module, action) !== 'all') {
    return <UnauthorizedPage module={module} action={action} scope={scope} />;
  }

  return <>{children}</>;
};
```

**Uso:**

```typescript
// apps/web/src/app/buildRoutes.tsx
<Route
  path="/work-orders"
  element={
    <ProtectedRoute module={Module.WORK_ORDERS} action={PermissionAction.VIEW}>
      <WorkOrdersPage />
    </ProtectedRoute>
  }
/>

<Route
  path="/work-orders/:id/edit"
  element={
    <ProtectedRoute module={Module.WORK_ORDERS} action={PermissionAction.EDIT}>
      <EditWorkOrderPage />
    </ProtectedRoute>
  }
/>
```

---

### 2️⃣ Protección Granular de Acciones

**Objetivo:** Controlar visibilidad y funcionalidad de botones/formularios según permisos.

#### `PermissionGate` Component

```typescript
// apps/web/src/shared/components/PermissionGate.tsx
interface PermissionGateProps {
  module: Module;
  action: PermissionAction;
  scope?: 'all' | 'own';
  resourceOwnerId?: string; // Para validación de scope "own"
  fallback?: React.ReactNode;
  children: React.ReactNode;
}

export const PermissionGate: React.FC<PermissionGateProps> = ({
  module,
  action,
  scope,
  resourceOwnerId,
  fallback,
  children,
}) => {
  const { can, getScope } = usePermissions();
  const { user } = useAuth();

  // Validar permiso básico
  if (!can(module, action)) {
    return fallback || null;
  }

  // Validar scope "own" si es necesario
  if (scope === 'own' || getScope(module, action) === 'own') {
    if (!resourceOwnerId || resourceOwnerId !== user?.id) {
      return fallback || null;
    }
  }

  return <>{children}</>;
};
```

**Uso:**

```typescript
// En un componente de Work Order Detail
<PermissionGate module={Module.WORK_ORDERS} action={PermissionAction.EDIT}>
  <Button onClick={handleEdit}>
    <Edit className="h-4 w-4" />
    Edit Work Order
  </Button>
</PermissionGate>

<PermissionGate 
  module={Module.WORK_ORDERS} 
  action={PermissionAction.DELETE}
  fallback={<Tooltip>You don't have permission to delete</Tooltip>}
>
  <Button variant="destructive" onClick={handleDelete}>
    <Trash className="h-4 w-4" />
    Delete
  </Button>
</PermissionGate>
```

---

### 3️⃣ Página de "Sin Permisos" Estandarizada

**Objetivo:** UI consistente para mostrar accesos denegados.

#### `UnauthorizedPage` Component

```typescript
// apps/web/src/shared/pages/UnauthorizedPage.tsx
interface UnauthorizedPageProps {
  module?: Module;
  action?: PermissionAction;
  scope?: string;
  message?: string;
}

export const UnauthorizedPage: React.FC<UnauthorizedPageProps> = ({
  module,
  action,
  scope,
  message,
}) => {
  const { t } = useI18n();
  const navigate = useNavigate();

  return (
    <div className="flex min-h-[calc(100vh-4rem)] items-center justify-center p-6">
      <Card className="max-w-md">
        <CardHeader>
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-destructive/10">
            <ShieldAlert className="h-8 w-8 text-destructive" />
          </div>
          <CardTitle className="text-center text-2xl">
            {t('errors.unauthorized.title')}
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-muted-foreground text-center">
            {message || t('errors.unauthorized.message')}
          </p>
          
          {module && (
            <div className="bg-muted rounded-lg p-4 text-sm">
              <p><strong>Module:</strong> {module}</p>
              {action && <p><strong>Action:</strong> {action}</p>}
              {scope && <p><strong>Required Scope:</strong> {scope}</p>}
            </div>
          )}

          <div className="flex gap-2">
            <Button variant="outline" className="w-full" onClick={() => navigate(-1)}>
              {t('common.goBack')}
            </Button>
            <Button className="w-full" onClick={() => navigate('/dashboard')}>
              {t('common.goToDashboard')}
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};
```

---

### 4️⃣ Audit Logging de Accesos

**Objetivo:** Registrar intentos de acceso no autorizados para seguridad y compliance.

#### `AuditService`

```typescript
// apps/web/src/shared/services/auditService.ts
export interface AuditLog {
  id: string;
  timestamp: string;
  userId: string;
  userEmail: string;
  action: 'ACCESS_DENIED' | 'ACCESS_GRANTED' | 'PERMISSION_CHECK';
  module: Module;
  permissionAction: PermissionAction;
  resourceId?: string;
  details?: string;
  ipAddress?: string;
  userAgent?: string;
}

class AuditService {
  async logAccessDenied(
    module: Module,
    action: PermissionAction,
    resourceId?: string,
    details?: string,
  ): Promise<void> {
    const log: Omit<AuditLog, 'id'> = {
      timestamp: new Date().toISOString(),
      userId: getCurrentUserId(),
      userEmail: getCurrentUserEmail(),
      action: 'ACCESS_DENIED',
      module,
      permissionAction: action,
      resourceId,
      details,
      ipAddress: await getClientIP(),
      userAgent: navigator.userAgent,
    };

    // Enviar al backend
    await fetch(buildBffUrl('/api/v1/audit/access-denied'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${getToken()}`,
      },
      body: JSON.stringify(log),
    });

    // También guardar en IndexedDB para offline
    await db.auditLogs.add(log);
  }

  async logAccessGranted(
    module: Module,
    action: PermissionAction,
    resourceId?: string,
  ): Promise<void> {
    // Similar a logAccessDenied pero con action: 'ACCESS_GRANTED'
  }
}

export const auditService = new AuditService();
```

**Integración en ProtectedRoute:**

```typescript
export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  module,
  action,
  children,
}) => {
  const { can } = usePermissions();

  if (!can(module, action)) {
    // 🔥 Log de acceso denegado
    auditService.logAccessDenied(module, action, window.location.pathname);
    return <UnauthorizedPage module={module} action={action} />;
  }

  // 🔥 Log de acceso concedido (opcional, solo en rutas críticas)
  if (module === Module.SETTINGS || module === Module.USERS) {
    auditService.logAccessGranted(module, action, window.location.pathname);
  }

  return <>{children}</>;
};
```

---

### 5️⃣ Tests de RBAC

**Objetivo:** Validar que el sistema de permisos funcione correctamente.

#### Unit Tests

```typescript
// apps/web/src/shared/components/__tests__/ProtectedRoute.spec.tsx
describe('ProtectedRoute', () => {
  it('should render children when user has permission', () => {
    const { container } = render(
      <ProtectedRoute module={Module.WORK_ORDERS} action={PermissionAction.VIEW}>
        <div data-testid="protected-content">Content</div>
      </ProtectedRoute>,
      {
        wrapper: createMockAuthProvider({ role: 'manager' }),
      },
    );

    expect(screen.getByTestId('protected-content')).toBeInTheDocument();
  });

  it('should show UnauthorizedPage when user lacks permission', () => {
    const { container } = render(
      <ProtectedRoute module={Module.SETTINGS} action={PermissionAction.EDIT}>
        <div data-testid="protected-content">Content</div>
      </ProtectedRoute>,
      {
        wrapper: createMockAuthProvider({ role: 'mobile_technician' }),
      },
    );

    expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument();
    expect(screen.getByText(/unauthorized/i)).toBeInTheDocument();
  });

  it('should validate scope "own" correctly', () => {
    const { container } = render(
      <ProtectedRoute 
        module={Module.WORK_ORDERS} 
        action={PermissionAction.EDIT}
        scope="own"
      >
        <div data-testid="protected-content">Content</div>
      </ProtectedRoute>,
      {
        wrapper: createMockAuthProvider({ 
          role: 'mobile_technician',
          id: 'user-123',
        }),
      },
    );

    // Technician can only edit their own WOs
    // This test would need more context (current WO owner)
  });
});
```

#### E2E Tests (Playwright)

```typescript
// apps/web/tests/e2e/rbac.spec.ts
test('Manager can access all work orders', async ({ page }) => {
  await loginAs(page, 'manager@trackworks.demo');
  
  await page.goto('/work-orders');
  await expect(page.getByRole('heading', { name: /work orders/i })).toBeVisible();
  
  // Manager should see "Create" button
  await expect(page.getByRole('button', { name: /create/i })).toBeVisible();
});

test('Mobile Technician can only see assigned work orders', async ({ page }) => {
  await loginAs(page, 'tech1@trackworks.demo');
  
  await page.goto('/work-orders');
  
  // Should only see WOs assigned to them
  const woCards = await page.locator('[data-testid="work-order-card"]').all();
  
  for (const card of woCards) {
    const assignedTo = await card.locator('[data-testid="assigned-to"]').textContent();
    expect(assignedTo).toContain('tech1@trackworks.demo');
  }
});

test('Mobile Technician cannot access Settings', async ({ page }) => {
  await loginAs(page, 'tech1@trackworks.demo');
  
  await page.goto('/settings');
  
  // Should be redirected to Unauthorized page
  await expect(page.getByText(/you don't have permission/i)).toBeVisible();
});
```

---

## 📦 Estructura de Archivos Propuesta

```
apps/web/src/
├─ shared/
│   ├─ components/
│   │   ├─ ProtectedRoute.tsx          # Middleware de rutas
│   │   ├─ PermissionGate.tsx          # Control de acciones
│   │   └─ __tests__/
│   │       ├─ ProtectedRoute.spec.tsx
│   │       └─ PermissionGate.spec.tsx
│   ├─ pages/
│   │   └─ UnauthorizedPage.tsx         # Página de acceso denegado
│   └─ services/
│       └─ auditService.ts              # Audit logging
├─ domains/
│   └─ auth/
│       ├─ hooks/
│       │   └─ usePermissions.ts        # ✅ Ya existe, mejorar
│       ├─ types/
│       │   └─ permission.types.ts      # ✅ Ya existe
│       └─ config/
│           └─ rolePermissions.ts       # Matriz de permisos ejecutable
└─ tests/
    └─ e2e/
        └─ rbac.spec.ts                 # Tests E2E de RBAC
```

---

## 🔄 Plan de Implementación (2-3 días)

### **Día 1: Componentes Base**

#### Morning (4h)

1. **Crear `ProtectedRoute` component** (1.5h)
   - Implementar validación básica
   - Integrar con `usePermissions`
   - Añadir logging de accesos denegados

2. **Crear `UnauthorizedPage`** (1h)
   - UI consistente con design system
   - i18n completo
   - Navegación de vuelta

3. **Crear `PermissionGate` component** (1.5h)
   - Validación granular de acciones
   - Soporte para scope "own"
   - Fallback customizable

#### Afternoon (4h)

4. **Implementar `AuditService`** (2h)
   - Logging de accesos denegados
   - Persistencia en IndexedDB
   - Integración con backend (mock)

5. **Unit tests básicos** (2h)
   - Tests de `ProtectedRoute`
   - Tests de `PermissionGate`

---

### **Día 2: Integración y Refactoring**

#### Morning (4h)

6. **Refactorizar rutas existentes** (2h)
   - Envolver rutas de Work Orders con `ProtectedRoute`
   - Envolver rutas de PM Scheduler con `ProtectedRoute`
   - Envolver rutas de Estimates con `ProtectedRoute`

7. **Refactorizar botones/acciones** (2h)
   - Añadir `PermissionGate` en botones críticos (Edit, Delete, Approve)
   - Work Orders detail page
   - Estimates detail page

#### Afternoon (4h)

8. **Mejorar `usePermissions` hook** (2h)
   - Añadir cache de permisos
   - Optimizar validaciones
   - Añadir helper `canAny`, `canAll`

9. **Crear `rolePermissions.ts` config** (2h)
   - Matriz ejecutable de permisos
   - Basada en `ROLES_AND_DOMAINS_COMPLETE_MATRIX.md`
   - TypeSafe

---

### **Día 3: Tests y Documentación**

#### Morning (4h)

10. **Tests E2E con Playwright** (2h)
    - Test de acceso Manager
    - Test de acceso Technician (scope "own")
    - Test de acceso denegado

11. **Tests de integración** (2h)
    - Flujo completo: Login → Access → Denied
    - Audit logs funcionando
    - Validación de scope

#### Afternoon (4h)

12. **Documentación técnica** (2h)
    - Guía de uso de `ProtectedRoute`
    - Guía de uso de `PermissionGate`
    - Ejemplos de casos comunes

13. **ADR (Architecture Decision Record)** (1h)
    - Decisión de implementar RBAC middleware
    - Trade-offs y alternativas
    - Futuras mejoras

14. **Demo y validación** (1h)
    - Demo con diferentes roles
    - Validar accesos denegados
    - Validar audit logs

---

## 🎯 Criterios de Éxito

### Funcionales

- [ ] `ProtectedRoute` valida permisos antes de renderizar
- [ ] `PermissionGate` controla visibilidad de acciones
- [ ] `UnauthorizedPage` se muestra cuando no hay permisos
- [ ] Audit logs registran accesos denegados
- [ ] Scope "own" funciona correctamente (technicians solo ven sus WOs)

### Técnicos

- [ ] Tests unitarios con >80% cobertura
- [ ] Tests E2E validando 3 roles diferentes
- [ ] Sin degradación de performance (< 10ms overhead por validación)
- [ ] i18n completo en español e inglés
- [ ] Documentación técnica completa

### Seguridad

- [ ] No se puede bypassear RBAC en navegación directa por URL
- [ ] Botones/acciones ocultos cuando no hay permiso
- [ ] Audit logs persisten incluso en modo offline
- [ ] Tokens de sesión validados en cada validación de permiso

---

## 🚧 Riesgos y Mitigaciones

### Riesgo 1: Performance Overhead

**Descripción:** Validar permisos en cada renderizado puede ser costoso.

**Mitigación:**
- Cache de permisos en memoria
- Memoización de resultados (`useMemo`)
- Validación lazy (solo cuando es necesario)

---

### Riesgo 2: Breaking Changes

**Descripción:** Añadir `ProtectedRoute` puede romper rutas existentes.

**Mitigación:**
- Refactorizar de forma incremental (1 dominio a la vez)
- Tests antes y después de cada cambio
- Feature flag para activar/desactivar RBAC

---

### Riesgo 3: Inconsistencia con Backend

**Descripción:** Permisos del frontend no coinciden con backend.

**Mitigación:**
- Validación redundante en frontend y backend
- Endpoint `/api/v1/permissions/validate` para verificar
- Tests de integración frontend ↔ backend

---

## 💡 Mejoras Futuras (Post-Implementación)

### 1️⃣ Permisos Dinámicos desde Backend

Actualmente, los permisos están hardcodeados en el frontend. Ideal sería que el backend devuelva la matriz de permisos:

```typescript
// GET /api/v1/permissions/user/{userId}
{
  "userId": "user-mgr-001",
  "role": "manager",
  "permissions": [
    { "module": "work_orders", "actions": ["view", "create", "edit", "delete"] },
    { "module": "estimates", "actions": ["view", "create", "approve"] },
    // ...
  ]
}
```

### 2️⃣ Permisos Granulares por Recurso

Permisos a nivel de recurso individual (p. ej., "user-123 puede editar WO-456 pero no WO-789"):

```typescript
<PermissionGate 
  module={Module.WORK_ORDERS} 
  action={PermissionAction.EDIT}
  resourceId={workOrder.id}
  resourceOwnerId={workOrder.assignedTo}
>
  <Button onClick={handleEdit}>Edit</Button>
</PermissionGate>
```

### 3️⃣ Permisos Temporales (TTL)

Permisos que expiran después de cierto tiempo (p. ej., "Technician puede editar WO durante 2 horas después de completarla"):

```typescript
{
  "module": "work_orders",
  "action": "edit",
  "resourceId": "WO-123",
  "expiresAt": "2025-12-31T23:59:59Z"
}
```

### 4️⃣ Dashboard de Audit Logs

UI para administradores donde puedan ver todos los accesos denegados:

```
/admin/audit-logs
- Filtros: Fecha, Usuario, Módulo, Acción
- Export CSV
- Alertas de intentos sospechosos
```

---

## 📚 Referencias

### Documentos Relacionados

- [Matriz Completa de Roles y Dominios](../ROLES_AND_DOMAINS_COMPLETE_MATRIX.md)
- [Fix Auth Flow Complete](../fixes/FIX_AUTH_FLOW_COMPLETE.md)
- [Architecture Guide](../architecture/ARCHITECTURE_GUIDE_FINAL_SUMMARY.md)

### Librerías Recomendadas

- **CASL** - https://casl.js.org/ (Alternativa más avanzada)
- **Permify** - https://permify.co/ (SaaS para RBAC)
- **Casbin** - https://casbin.org/ (Policy-based access control)

**Nota:** Para TrackWorks, una implementación custom es suficiente por ahora. Considerar librerías externas solo si se requieren permisos muy complejos (p. ej., ABAC - Attribute-Based Access Control).

---

## 🎓 Insights para CodeSpartan

Jorge, este RBAC middleware es **crítico** porque:

### 1️⃣ Fundamento de Seguridad

Sin un sistema robusto de RBAC:
- Technicians podrían ver WOs de otros
- Parts Dept podría acceder a Settings
- Customer podría ver datos de otros clientes

**Consecuencia:** Vulnerabilidad de seguridad crítica en producción.

---

### 2️⃣ Escalabilidad

Con RBAC implementado correctamente:
- Añadir nuevos roles es trivial
- Añadir nuevos dominios no requiere cambiar lógica de permisos
- Tests automáticos validan restricciones

**Consecuencia:** Proyecto preparado para crecer sin refactors masivos.

---

### 3️⃣ Portfolio Value

Este RBAC es **portfolio-worthy** porque:
- Demuestra pensamiento de seguridad desde el diseño
- Arquitectura limpia y extensible
- Tests completos (unit + E2E)
- Audit logging para compliance

**Título para post:** _"Building a Production-Ready RBAC System in React"_

---

## ✅ Checklist de Implementación

### Pre-Requisitos

- [ ] Auth flow funcionando correctamente ✅ (Ya hecho)
- [ ] Roles definidos en backend ✅ (Ya existe en mock-server)
- [ ] Matriz de permisos documentada ✅ (Ya existe)

### Componentes

- [ ] `ProtectedRoute` component
- [ ] `PermissionGate` component
- [ ] `UnauthorizedPage` component
- [ ] `AuditService` service
- [ ] `rolePermissions.ts` config

### Tests

- [ ] Unit tests de `ProtectedRoute`
- [ ] Unit tests de `PermissionGate`
- [ ] E2E tests con 3 roles (Manager, Technician, Parts Dept)
- [ ] Integration tests de audit logs

### Integración

- [ ] Refactorizar rutas de Work Orders
- [ ] Refactorizar rutas de PM Scheduler
- [ ] Refactorizar rutas de Estimates
- [ ] Refactorizar botones/acciones críticas

### Documentación

- [ ] Guía de uso de RBAC
- [ ] ADR de decisión de arquitectura
- [ ] README con ejemplos
- [ ] Comentarios JSDoc en componentes

### Validación

- [ ] Demo con Manager (acceso completo)
- [ ] Demo con Technician (scope "own")
- [ ] Demo con Parts Dept (solo Inventory/PO)
- [ ] Audit logs funcionando

---

## 🚀 Próximos Pasos

**Después de implementar RBAC:**

1. **Scaffolding de dominios pendientes** (Purchase Orders, Invoices, etc.)
   - Con RBAC ya listo, cada dominio nuevo ya aplica permisos desde el principio

2. **Implementar Purchase Orders** (MVP funcional)
   - Primer dominio adicional completo con RBAC integrado

3. **Tests E2E de flujos críticos**
   - Login → Access → Create WO → Edit WO → Close WO (con diferentes roles)

---

## 💪 Mensaje Final

Jorge, este RBAC middleware es **la base sobre la que construir todos los dominios restantes**. Sin él, cada dominio tendría que implementar su propia lógica de permisos (duplicación + bugs).

**Inversión:** 2-3 días  
**ROI:** 🔥🔥🔥 Seguridad + Escalabilidad + Mantenibilidad

**¿Listo para hacerlo?** 💪

---

**Fin del documento.** 🎯

