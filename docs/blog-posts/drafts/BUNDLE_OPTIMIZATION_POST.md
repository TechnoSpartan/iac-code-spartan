# Cómo redujimos el bundle de TrackWorks un 65% sin tocar el negocio

**Autor:** Jorge Carballo - CodeSpartan  
**Fecha:** Enero 2026
**Tiempo de lectura:** TL:DR minutos  
**Nivel:** Intermedio  
**Tags:** #performance, #vite, #react, #optimization, #web-vitals

---

## TL;DR (Resumen Ejecutivo)

Reducimos el bundle principal de 1,011 KB a 356 KB (-65%) y el tiempo de carga inicial de ~4s a ~1.5s (-62%) simplemente repensando cómo empaquetábamos el frontend, no reescribiendo la aplicación.

La clave fue usar `manualChunks` en Vite para separar lo que casi nunca cambia (React, router, librerías pesadas) de lo que tocamos en cada sprint (nuestro código de negocio).

---

## El Problema / Contexto

El dolor real: un bundle obeso y usuarios esperando
TrackWorks no es un TODO app. Es una bestia empresarial con:
• 22 dominios de negocio
• Múltiples librerías de UI (Radix UI, Recharts)
• Funcionalidades de exportación PDF
• Soporte i18n multilenguaje
• PWA con offline-first

Un día, lanzamos  `pnpm build`  y nos mira esto:\[2-3 líneas con los puntos clave y resultados concretos][Describe el problema o situación inicial. ¿Por qué es importante?]

```bash
dist/assets/index-DfXy8Z3a.js   1,011.45 kB │ gzip: 298.12 kB
dist/assets/vendor-abc123.js      478.23 kB │ gzip: 142.67 kB

⚠️ Some chunks are larger than 500 kB after minification.
Consider code splitting to reduce chunk sizes.
```

Traducción: teníamos un bundle obeso intentando entrar por la puerta estrecha de un móvil con 4G regulero.
Impacto real:

- Tiempo hasta interactivo (TTI): ~4 segundos
- Lighthouse Performance Score: ~60
- Usuarios en móvil viendo pantallas en blanco más tiempo del razonable

Antes de tocar nada, confirmamos que el problema era JavaScript de más en el arranque, no el backend ni la red.

---

## Estrategia: pensar en chunks, no en “un bundle enorme”

Vite (y debajo, Rollup) permiten controlar cómo se dividen los bundles con  `manualChunks` .
La idea: agrupar por:

- Frecuencia de cambio → lo que casi no cambia es oro para la caché
- Contexto de uso → no todo se necesita en el primer render

Antes: configuración por defecto

Todo el vendor iba prácticamente junto, sin criterio específico:

```typescript
// vite.config.ts
export default defineConfig({
  build: {
    // Sin configuración - todo en un solo vendor chunk
  },
});
```

### Después: chunk splitting con intención

Definimos chunks a partir de roles claros: core de React, router, charts, UI, PDF, i18n, estado, etc.

```typescript
// vite.config.ts
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          // React core - cambia muy poco, excelente caché
          if (
            id.includes("node_modules/react/") ||
            id.includes("node_modules/react-dom/")
          ) {
            return "vendor-react";
          }

          // React Router
          if (
            id.includes("node_modules/react-router") ||
            id.includes("node_modules/@remix-run")
          ) {
            return "vendor-router";
          }

          // Charts (Recharts + D3) - grande pero solo en dashboards
          if (
            id.includes("node_modules/recharts") ||
            id.includes("node_modules/d3")
          ) {
            return "vendor-charts";
          }

          // Radix UI - componentes de UI
          if (id.includes("node_modules/@radix-ui")) {
            return "vendor-radix";
          }

          // Lucide icons
          if (id.includes("node_modules/lucide-react")) {
            return "vendor-icons";
          }

          // Date utilities
          if (
            id.includes("node_modules/date-fns") ||
            id.includes("node_modules/dayjs")
          ) {
            return "vendor-date";
          }

          // Form handling
          if (
            id.includes("node_modules/react-hook-form") ||
            id.includes("node_modules/@hookform")
          ) {
            return "vendor-forms";
          }

          // State management
          if (id.includes("node_modules/zustand")) {
            return "vendor-state";
          }

          // PDF generation - solo cuando exportan
          if (
            id.includes("node_modules/html2canvas") ||
            id.includes("node_modules/jspdf")
          ) {
            return "vendor-pdf";
          }

          // TanStack (Query, Table)
          if (id.includes("node_modules/@tanstack")) {
            return "vendor-tanstack";
          }

          // i18n
          if (
            id.includes("node_modules/i18next") ||
            id.includes("node_modules/react-i18next")
          ) {
            return "vendor-i18n";
          }

          // Resto de vendors
          if (id.includes("node_modules/")) {
            return "vendor-misc";
          }
        },
      },
    },
  },
});
```

No hay magia: simplemente le contamos al bundler cómo está organizada nuestra aplicación.

### Resultados: mismos features, app que se siente 3x más rápida

Output del build

```bash
dist/assets/index-abc123.js           356.12 kB │ gzip: 102.34 kB
dist/assets/vendor-react-xyz789.js     45.23 kB │ gzip:  14.67 kB
dist/assets/vendor-router-def456.js    32.45 kB │ gzip:  10.23 kB
dist/assets/vendor-charts-ghi789.js   302.67 kB │ gzip:  89.12 kB
dist/assets/vendor-radix-jkl012.js    156.34 kB │ gzip:  45.67 kB
dist/assets/vendor-icons-mno345.js     89.23 kB │ gzip:  23.45 kB
dist/assets/vendor-pdf-pqr678.js      539.12 kB │ gzip: 156.78 kB
dist/assets/vendor-misc-stu901.js     406.45 kB │ gzip: 112.34 kB
```

---

## Comparativa

[Métricas concretas: tiempo ahorrado, costos, mejoras, etc.]

| Métrica                     | Antes    | Después | Mejora  |
| --------------------------- | -------- | ------- | ------- |
| Bundle principal (index.js) | 1,011 KB | 356 KB  | -65%    |
| Chunk más grande de página  | 478 KB   | 87 KB   | -82%    |
| Tiempo de carga inicial     | ~4s      | ~1.5s   | -62%    |
| Lighthouse Performance      | ~60      | 87 KB   | +25 pts |
| First Contentful Paint      | ~2s      | 87 KB   | -60%    |

No tocamos ni backend ni reglas de negocio. Solo reposicionamos el peso del JavaScript.

## Por qué funciona (de verdad)

### 1. La caché del navegador, por fin a tu favor

Antes:

- Un vendor bundle grande implicaba que cada cambio en código de negocio podía invalidar toda la caché.
- El usuario acababa descargando ~1 MB aunque apenas hubiéramos tocado una pantalla.

Después:

- React, router y compañía viven en sus propios chunks y casi nunca cambian.
- Nuestro código de dominio va en otros chunks que sí cambian a menudo.

En la práctica, conviertes tu frontend en una especie de monolito modular: las piezas estables se quedan quietas y el usuario solo baja lo que realmente ha cambiado.

### 2. Cargar lo pesado solo cuando hace falta

Librerías como  `html2canvas` o `jspdf`son perfectas candidatas a carga bajo demanda. No tiene sentido pagar su coste en frío si solo un porcentaje de usuarios exporta PDFs.

```typescript
// WorkOrderDetailPage.tsx - El PDF se carga solo al exportar
const handleExportPDF = async () => {
  // vendor-pdf.js (539 KB) se descarga aquí, no al inicio
  const { default: html2canvas } = await import('html2canvas');
  const { default: jsPDF } = await import('jspdf');
  // ... generar PDF
};
```

Aceptamos pagar el coste de descargar 500 KB en el momento en que alguien exporta, a cambio de no penalizar a todos los que solo quieren abrir la app y trabajar.

### 3. Aprovechar las descargas en paralelo

Los navegadores modernos pueden descargar varios archivos en paralelo.
 • Antes: 1 archivo grande = 1 cuello de botella.
 • Después: muchos archivos más pequeños = mejor aprovechamiento del ancho de banda.

## Otras optimizaciones que marcaron diferencia

1. Lazy loading de páginas
Todas las páginas se cargan dinámicamente a través de un  componentMap :

```typescript
// componentMap.ts
export const componentMap = {
  '@domains/work-orders/pages/WorkOrdersPage':
    () => import('@domains/work-orders/pages/WorkOrdersPage'),
  '@domains/estimates/pages/EstimatesPage':
    () => import('@domains/estimates/pages/EstimatesPage'),
  // ... 50+ páginas más
};
```

Solo cargas la pantalla que el usuario necesita, no las 50+ a la vez.

### 2. No exportar páginas en los `index.ts` de dominio

```typescript
// domains/work-orders/index.ts
// ❌ ANTES: Exportaba la página (se incluía en el bundle inicial)
// export { WorkOrdersPage } from './pages/WorkOrdersPage';

// ✅ DESPUÉS: Solo exporta tipos, hooks, stores
export * from './types';
export * from './hooks';
export { useWorkOrdersStore } from './stores';
// Páginas se cargan via componentMap
```

Esto evita que las páginas “se cuelen” en el bundle inicial por un simple `index.ts` demasiado generoso.

### 3. Minificación agresiva con Terser

```typescript
build: {
  minify: 'terser',
  terserOptions: {
    compress: {
      drop_console: true,    // Elimina console.log en prod
      drop_debugger: true,   // Elimina debugger statements
    },
  },
}
```

No te va a dar 65% de mejora, pero sí limpia ruido y reduce unos cuantos KB extra. Todo suma.

Lo siguiente en la lista: domar `vendor-pdf`  (539 KB)
Ese chunk todavía supera el umbral de 500 KB. El siguiente paso es aislar por completo la lógica de exportación y cargarla bajo demanda desde un único punto.

```typescript
// Implementación futura
const ExportPDFButton = () => {
  const [isExporting, setIsExporting] = useState(false);

  const handleExport = async () => {
    setIsExporting(true);
    // El chunk se descarga solo aquí
    const { generatePDF } = await import('@/shared/utils/pdfGenerator');
    await generatePDF();
    setIsExporting(false);
  };

  return (
    <Button onClick={handleExport} disabled={isExporting}>
      {isExporting ? 'Generando...' : 'Exportar PDF'}
    </Button>
  );
};
```

La idea: mover la complejidad a un util centralizado ( `pdfGenerator` ) y dejar el resto del código respirando.

## Pequeñas mejoras extra en el día a día

Memoización de columnas en tablas

```typescript
// ❌ ANTES: Se recrea en cada render
const columns = [
  { key: 'id', header: t('table.id') },
  { key: 'name', header: t('table.name') },
];

// ✅ DESPUÉS: Se memoiza
const columns = useMemo(() => [
  { key: 'id', header: t('table.id') },
  { key: 'name', header: t('table.name') },
], [t]);
```

No es una optimización de bundle en sí, pero ayuda a que las tablas se comporten mejor y reduzcan renders innecesarios.

## Herramientas que nos ayudaron a no ir a ciegas

### Analizar el bundle

```bash
# Instalar rollup-plugin-visualizer
pnpm add -D rollup-plugin-visualizer

# En vite.config.ts
import { visualizer } from 'rollup-plugin-visualizer';

plugins: [
  visualizer({
    filename: 'bundle-stats.html',
    open: true,
    gzipSize: true,
  }),
]
```

Ver el bundle en un gráfico duele… pero te dice exactamente dónde atacar.

### Medir Web Vitals en producción

```typescript
// src/main.tsx
import { getCLS, getFID, getLCP } from 'web-vitals';

getCLS(console.log);  // Cumulative Layout Shift
getFID(console.log);  // First Input Delay
getLCP(console.log);  // Largest Contentful Paint
```

Optimizar sin medir es adivinar. Esto te baja al mundo real.

---

## Conclusión

La optimización de bundles no es magia negra. Es aplicar arquitectura y sentido común al frontend:

- Mide primero. No optimices lo que no sabes que duele.
- Separa lo que cambia poco de lo que tocas cada semana. Deja que la caché juegue a tu favor.
- Carga lo pesado solo cuando alguien realmente lo necesita.

El resultado: una aplicación que carga 3x más rápido sin tocar una sola línea de código de negocio.

Piensa en chunks, no en “un sólo bundle gigante”.

**Piensa. Crea. Escala.**

---

## Call to Action

¿Te ha sido útil este artículo?

1. Compártelo en LinkedIn/Twitter
2. Déjame un comentario con tu experiencia
3. Si implementas algo similar, cuéntame qué tal fue

**¿Quieres ayuda implementando esto?**

Ofrezco consultorías de 1-2 horas para:

- Revisar tu setup actual
- Diseñar tu solución
- Implementar mejoras específicas

[Reserva una sesión →](https://www.codespartan.es/consultoria)

---

**Tags:** #performance, #vite, #react, #optimization, #web-vitals

---

_¿Preguntas? ¿Feedback? Contáctame en [jcarballo@codespartan.es](mailto:jcarballo@codespartan.es)_
