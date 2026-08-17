# Criterios de evaluación para agentes

Usa este documento como política base para revisar cambios, orientar agentes y validar si un trabajo está realmente listo.

## 1. Arquitectura limpia

### Objetivo
La lógica de negocio debe ser independiente del framework, la UI y la infraestructura.

### Normas
- El dominio no debe depender de Angular, React, Node, navegador ni librerías de UI.
- El dominio debe poder ejecutarse y probarse de forma aislada.
- Las dependencias deben apuntar hacia dentro.
- La capa de presentación no debe contener reglas de negocio.
- La infraestructura solo implementa detalles técnicos; no decide comportamiento funcional.
- Los adapters deben ser finos: traducen entradas y salidas.
- Las reglas compartidas deben vivir en TypeScript puro y no duplicarse por framework.
- Toda integración con APIs, storage, eventos, router o estado global debe quedar detrás de contratos claros.
- Los módulos deben tener responsabilidades cohesionadas y límites reconocibles.
- El diseño debe permitir cambios incrementales sin reescribir toda la aplicación.

### Antipatrones
- Componentes con lógica de negocio.
- Servicios tipo "god object".
- Core importando Angular o React.
- Reglas duplicadas en varios adapters.
- Mezcla de dominio, UI e infraestructura en un mismo módulo.

### Evidencias de cumplimiento
- Separación clara entre core, adapters e infraestructura.
- El core compila sin dependencias del framework.
- Hay tests unitarios del dominio sin UI.
- Cambiar de framework no obliga a reescribir la lógica de negocio.

## 2. SOLID

### Objetivo
Mantener un diseño robusto, extensible y comprensible.

### Normas

#### S — Single Responsibility Principle
- Cada módulo, clase o función debe tener un único motivo de cambio.
- Un componente visual no debe mezclar renderizado, reglas de negocio, red y transformación de datos.
- Un servicio no debe resolver responsabilidades de varios dominios.

#### O — Open/Closed Principle
- El comportamiento debe extenderse sin modificar continuamente código estable.
- Las variantes deben resolverse con composición, estrategias o adapters, no con `if/else` interminables.

#### L — Liskov Substitution Principle
- Toda implementación concreta debe respetar el contrato de la abstracción.
- No se deben crear tipos hijos que alteren el comportamiento esperado o rompan invariantes.

#### I — Interface Segregation Principle
- Las interfaces deben ser pequeñas y enfocadas.
- No se debe obligar a un consumidor a depender de métodos que no necesita.

#### D — Dependency Inversion Principle
- El dominio y la aplicación deben depender de abstracciones, no de implementaciones concretas.
- Los detalles técnicos deben enchufarse desde fuera.

### Antipatrones
- Clases gigantes con muchos motivos de cambio.
- Interfaces enormes.
- Herencias artificiales.
- Dependencias directas a implementaciones concretas desde el dominio.
- Módulos que se rompen al extender un caso nuevo.

### Evidencias de cumplimiento
- Interfaces pequeñas y expresivas.
- Bajo acoplamiento entre módulos.
- Sustitución segura de implementaciones.
- Testeo con mocks/fakes sin trucos raros.

## 3. DoR — Definition of Ready

### Objetivo
Ningún trabajo debe empezar si no está suficientemente preparado.

### Una tarea está Ready cuando
- Tiene objetivo de negocio claro.
- Tiene alcance definido y acotado.
- Se conocen entradas, salidas y comportamiento esperado.
- Tiene criterios de aceptación concretos y verificables.
- Se han identificado dependencias externas.
- Se ha revisado el impacto en contratos, arquitectura y compatibilidad.
- Se sabe qué módulos o repos se van a tocar.
- Se ha aclarado si aplica a core, adapter, aplicación o infraestructura.
- Se han identificado riesgos relevantes.
- La tarea es suficientemente pequeña para ejecutarse sin ambigüedad excesiva.

### No está Ready si
- La descripción es vaga.
- No hay criterios de aceptación.
- No se entiende el impacto funcional.
- No se sabe si rompe contratos.
- Se pretende "ya veremos sobre la marcha".

## 4. DoD — Definition of Done

### Objetivo
Nada se considera terminado si no cumple un mínimo de calidad técnica, funcional y documental.

### Una tarea está Done cuando
- Cumple los criterios de aceptación acordados.
- El comportamiento está validado.
- No rompe contratos existentes sin aprobación explícita.
- El código sigue las reglas de arquitectura del repositorio.
- Se han actualizado tests o se han creado los necesarios.
- El lint, build y validaciones obligatorias pasan.
- Se ha revisado el impacto en dependencias y configuración.
- Se ha actualizado la documentación afectada.
- Se han eliminado restos de código muerto o experimental.
- Se han identificado y documentado limitaciones, si las hubiera.
- El cambio es entendible para otro desarrollador sin contexto oculto.
- Se ha revisado la deuda técnica introducida o diferida.

### No está Done si
- "Funciona en mi máquina".
- Falta documentación.
- No hay validación mínima.
- Deja comportamientos inconsistentes.
- Introduce hacks no documentados.

## 5. DoTech — Definition of Technical Quality

### Objetivo
Asegurar una calidad técnica mínima medible y repetible.

### Normas
- No debe existir lógica de negocio en la capa visual.
- El repositorio debe tener una estructura coherente y reconocible.
- El tipado debe ser fuerte; `any` solo con justificación explícita.
- Los contratos deben estar centralizados o ser trazables.
- Los errores deben tratarse de forma explícita.
- El código muerto debe eliminarse.
- Las dependencias deben ser justificables y mantenerse bajo control.
- Las dependencias de producción deben revisarse por peso, uso y riesgo.
- Los módulos críticos deben ser testeables de forma aislada.
- La complejidad accidental debe reducirse de forma continua.
- Los cambios deben dejar el sistema igual o mejor que antes.
- Las reglas automáticas de linting, formateo y typecheck deben formar parte del flujo normal.
- Debe existir observabilidad mínima cuando aplique: logs útiles, errores trazables y comportamiento diagnosable.
- La seguridad no es opcional: no se exponen secretos y no se ignoran vulnerabilidades sin registrar riesgo.

### Indicadores mínimos sugeridos
- Build verde.
- Lint verde.
- Typecheck verde.
- Tests críticos verdes.
- Sin imports prohibidos entre capas.
- Sin duplicidad relevante de lógica de negocio.
- Sin vulnerabilidades críticas abiertas sin aceptación explícita del riesgo.
- Sin dependencias de producción no justificadas.

## 6. Reglas operativas para agentes

### El agente debe validar siempre
- Separación de capas.
- Ausencia de lógica de negocio en UI.
- Contaminación del core por frameworks.
- Acoplamiento entre módulos.
- Tamaño y responsabilidad de servicios/componentes.
- Calidad del tipado.
- Riesgo de dependencias de producción.
- Presencia de código muerto, duplicidad y bypasses.
- Cobertura de validaciones mínimas del DoD.
- Preparación suficiente según DoR.

### El agente no debe
- Dar por bueno un cambio solo porque compila.
- Aceptar hacks sin documentarlos.
- Considerar "Done" una tarea sin documentación o sin validación.
- Recomendar reescrituras masivas como primera opción.
- Confundir complejidad técnica con buen diseño.

## 7. Versión resumida para reglas YAML

```yaml
clean_architecture:
  - domain_must_be_framework_agnostic
  - ui_must_not_contain_business_logic
  - dependencies_must_point_inward
  - adapters_must_be_thin
  - shared_logic_must_live_in_core

solid:
  - modules_must_have_single_responsibility
  - behavior_should_be_extended_without_modifying_stable_code
  - implementations_must_respect_contracts
  - interfaces_must_be_small_and_focused
  - high_level_modules_must_depend_on_abstractions

dor:
  - business_goal_defined
  - scope_defined
  - acceptance_criteria_defined
  - dependencies_identified
  - architecture_impact_identified
  - affected_modules_identified

dod:
  - acceptance_criteria_met
  - no_unapproved_contract_breaking_changes
  - tests_updated
  - lint_passes
  - build_passes
  - docs_updated
  - technical_debt_documented_if_deferred

dotech:
  - no_business_logic_in_ui
  - strong_typing_required
  - no_unjustified_any
  - dependency_risk_reviewed
  - dead_code_removed
  - errors_handled_explicitly
  - architecture_boundaries_respected
  - security_issues_not_ignored
```

