# Guía de Publicación en WordPress (Hostinger)

Instrucciones específicas para publicar el artículo en WordPress administrado por Hostinger.

---

## 📝 Preparación del Contenido

### 1. Formato del Texto

WordPress usa el editor Gutenberg (bloques). Recomendaciones:

- **Títulos:** Usa bloques de "Encabezado" (H2, H3, H4)
- **Párrafos:** Bloque "Párrafo" normal
- **Código:** Bloque "Código" o "Código personalizado"
- **Listas:** Bloques "Lista" (con viñetas o numerada)
- **Citas:** Bloque "Cita" para los callouts/tips

### 2. Plugins Recomendados

**Esenciales:**
- **SyntaxHighlighter Evolved** o **WP Code Highlight** - Para código con colores
- **Smush** o **ShortPixel** - Optimización de imágenes
- **Yoast SEO** o **Rank Math** - SEO (alt text, meta descriptions)

**Opcionales pero útiles:**
- **Table of Contents Plus** - Tabla de contenidos automática
- **WP Callout Boxes** - Para los tips/advertencias con estilo
- **Lazy Load** - Si no está activado por defecto

---

## 🖼️ Subir Imágenes a WordPress

### Paso a Paso

1. **Prepara las imágenes:**
   - Optimiza con [TinyPNG](https://tinypng.com/)
   - Renombra con nombres descriptivos: `pipeline-cicd-diagrama.png`

2. **Sube a WordPress:**
   - Ve a "Medios" → "Añadir nuevo"
   - Arrastra las imágenes o haz click en "Seleccionar archivos"
   - Espera a que se suban todas

3. **Configura cada imagen:**
   - **Título:** Descripción breve (ej: "Diagrama del Pipeline CI/CD")
   - **Texto alternativo (Alt Text):** **MUY IMPORTANTE para SEO**
     - Ejemplo: "Diagrama de flujo del pipeline CI/CD mostrando los 5 jobs secuenciales"
   - **Descripción:** Opcional, pero útil para organización

4. **Inserta en el artículo:**
   - Coloca el cursor donde quieras la imagen
   - Click en "+" → "Imagen"
   - Selecciona la imagen subida
   - Ajusta tamaño (recomendado: "Tamaño completo" o "Grande")
   - Añade una leyenda si es necesario

---

## 💻 Insertar Código con Syntax Highlighting

### Opción 1: Plugin SyntaxHighlighter Evolved

1. **Instala el plugin:**
   - Ve a "Plugins" → "Añadir nuevo"
   - Busca "SyntaxHighlighter Evolved"
   - Instala y activa

2. **Usa en el artículo:**
   ```
   [code language="yaml"]
   jobs:
     deploy:
       runs-on: ubuntu-latest
   [/code]
   ```

### Opción 2: Bloque de Código de Gutenberg

1. Añade bloque "Código" o "Código personalizado"
2. Pega el código
3. Selecciona el lenguaje en la barra lateral (si está disponible)

### Opción 3: HTML Personalizado

Si prefieres más control:

```html
<pre><code class="language-yaml">
jobs:
  deploy:
    runs-on: ubuntu-latest
</code></pre>
```

---

## 📊 Insertar Diagramas Mermaid

WordPress no soporta Mermaid nativamente. Opciones:

### Opción 1: Convertir a Imagen (Recomendado)

1. Ve a [mermaid.live](https://mermaid.live/)
2. Pega el código Mermaid
3. Click en "Actions" → "Download PNG"
4. Sube la imagen a WordPress como cualquier otra imagen

### Opción 2: Plugin Mermaid (Si existe)

Busca plugins como "Mermaid Diagrams" en el repositorio de WordPress. Revisa compatibilidad con tu versión.

### Opción 3: Embed desde Mermaid Live

1. En mermaid.live, crea el diagrama
2. Click en "Actions" → "Share" → "Copy Link"
3. Usa un bloque HTML personalizado:
   ```html
   <iframe src="URL_DEL_DIAGRAMA" width="100%" height="600"></iframe>
   ```

**Nota:** La opción 1 (imagen PNG) es la más compatible y rápida.

---

## 🎨 Crear Callout Boxes (Tips, Advertencias, etc.)

### Opción 1: Plugin WP Callout Boxes

1. Instala "WP Callout Boxes"
2. Usa shortcodes:
   ```
   [callout type="tip"]Tu texto aquí[/callout]
   [callout type="warning"]Tu advertencia[/callout]
   [callout type="success"]Tu éxito[/callout]
   ```

### Opción 2: CSS Personalizado + Bloque Cita

1. Ve a "Apariencia" → "Personalizar" → "CSS adicional"
2. Añade este CSS:

```css
.callout-tip {
    background: #e7f3ff;
    border-left: 4px solid #2196F3;
    padding: 15px;
    margin: 20px 0;
    border-radius: 4px;
}

.callout-warning {
    background: #fff3cd;
    border-left: 4px solid #ffc107;
    padding: 15px;
    margin: 20px 0;
    border-radius: 4px;
}

.callout-success {
    background: #d4edda;
    border-left: 4px solid #28a745;
    padding: 15px;
    margin: 20px 0;
    border-radius: 4px;
}
```

3. Usa bloques "Cita" y añade la clase CSS en "Avanzado" → "Clase CSS adicional"

### Opción 3: HTML Personalizado

```html
<div class="callout-tip">
    <strong>💡 Tip:</strong> Tu texto aquí
</div>
```

---

## 📈 Insertar Gráficos Comparativos

### Opción 1: Imagen desde Canva/Google Sheets

1. Crea el gráfico en Canva o Google Sheets
2. Exporta como PNG (1200px ancho)
3. Optimiza con TinyPNG
4. Sube a WordPress como imagen normal

### Opción 2: Tabla de WordPress

1. Añade bloque "Tabla"
2. Crea la tabla con los datos
3. Aplica estilos desde "Estilos de tabla" en la barra lateral

### Opción 3: HTML Table con Estilos

```html
<table style="width: 100%; border-collapse: collapse;">
    <thead>
        <tr style="background: #f0f0f0;">
            <th style="padding: 10px; border: 1px solid #ddd;">Métrica</th>
            <th style="padding: 10px; border: 1px solid #ddd;">Manual</th>
            <th style="padding: 10px; border: 1px solid #ddd;">Automatizado</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td style="padding: 10px; border: 1px solid #ddd;">Tiempo Deploy</td>
            <td style="padding: 10px; border: 1px solid #ddd;">35 min</td>
            <td style="padding: 10px; border: 1px solid #ddd;">2 min</td>
        </tr>
    </tbody>
</table>
```

---

## 🔍 SEO y Optimización

### 1. Meta Descripción

- Ve a "Yoast SEO" o "Rank Math" en la barra lateral del editor
- Añade meta descripción (150-160 caracteres):
  ```
  Aprende a construir un pipeline CI/CD profesional en 24 horas. Deploy automatizado, rollback automático, zero downtime. Stack: GitHub Actions, Docker, Traefik.
  ```

### 2. Imagen Destacada

- Sube una imagen destacada (1200x630px recomendado)
- Representa el tema del artículo
- Se mostrará en redes sociales cuando compartas

### 3. Alt Text en Todas las Imágenes

**Ejemplos:**
- "Diagrama del pipeline CI/CD mostrando los 5 jobs secuenciales"
- "Comparativa de tiempos de deploy manual vs automatizado"
- "Captura de pantalla de GitHub Actions workflow ejecutándose"
- "Notificación de Discord mostrando deploy exitoso con métricas"

### 4. URLs Amigables

WordPress genera URLs automáticamente. Asegúrate de que sea:
- `tu-dominio.com/cicd-profesional-24-horas`
- No uses caracteres especiales
- Incluye palabras clave

### 5. Etiquetas y Categorías

**Categorías sugeridas:**
- DevOps
- CI/CD
- Tutoriales
- Automatización

**Etiquetas sugeridas:**
- GitHub Actions
- Docker
- CI/CD
- DevOps
- Automatización
- Deploy
- Pipeline
- Traefik
- Terraform

---

## 📱 Verificación Responsive

Antes de publicar, verifica:

1. **Desktop (1920x1080):**
   - Las imágenes se ven bien
   - El texto es legible
   - Los diagramas no se cortan

2. **Tablet (768px):**
   - Las imágenes se adaptan
   - El texto no es demasiado pequeño

3. **Móvil (375px):**
   - Las imágenes se ajustan automáticamente
   - El código no se desborda (usa scroll horizontal)
   - Los diagramas son legibles

**Cómo verificar:**
- Usa las herramientas de desarrollador del navegador (F12)
- O usa [Responsive Design Checker](https://www.responsivedesignchecker.com/)

---

## 🚀 Checklist Final Antes de Publicar

- [ ] Todas las imágenes subidas y con alt text
- [ ] Código con syntax highlighting funcionando
- [ ] Diagramas convertidos a imágenes y subidos
- [ ] Callout boxes con estilos aplicados
- [ ] Meta descripción añadida
- [ ] Imagen destacada configurada
- [ ] Categorías y etiquetas asignadas
- [ ] URL amigable configurada
- [ ] Verificado en desktop, tablet y móvil
- [ ] Enlaces internos funcionando (si los hay)
- [ ] Enlaces externos abren en nueva pestaña (target="_blank")
- [ ] Tabla de contenidos añadida (si usas plugin)
- [ ] Botones de compartir en redes sociales visibles
- [ ] Formato de fecha correcto
- [ ] Autor asignado correctamente

---

## 🎯 Estructura Sugerida del Artículo en WordPress

```
1. Imagen Destacada
2. Título (H1)
3. Meta información (fecha, autor, tiempo de lectura)
4. Tabla de contenidos (si usas plugin)
5. TL;DR (H2)
6. Infografía Manual vs Automatizado
7. El Problema (H2)
8. La Visión (H2)
9. La Arquitectura (H2)
   - Diagrama de Arquitectura
   - Diagrama del Pipeline
10. El Workflow (H2)
    - Captura GitHub Actions
    - Captura Docker Build
    - Diagrama de Rollback
11. Los Números (H2)
    - Gráfico Comparativo
12. Lecciones Aprendidas (H2)
13. Cómo Replicar (H2)
14. Stack Completo (H2)
15. Conclusión (H2)
16. Call to Action (H2)
17. Autor y contacto
```

---

## 💡 Tips Adicionales para Hostinger

1. **Caché:**
   - Hostinger suele tener caché activado
   - Después de publicar, limpia la caché (si tienes acceso)
   - O espera unos minutos para que se actualice

2. **CDN:**
   - Si tienes CDN activado, las imágenes cargarán más rápido
   - Asegúrate de que las imágenes estén optimizadas

3. **SSL:**
   - Verifica que tu sitio tenga SSL activado (https://)
   - WordPress suele redirigir automáticamente

4. **Backup:**
   - Antes de hacer cambios grandes, haz backup
   - Hostinger suele tener backups automáticos, pero verifica

---

## 🆘 Solución de Problemas Comunes

### Las imágenes no se ven
- Verifica que las imágenes estén subidas correctamente
- Revisa los permisos de archivos
- Limpia la caché

### El código no tiene colores
- Verifica que el plugin de syntax highlighting esté activado
- Revisa que uses el shortcode correcto
- Prueba con otro plugin

### Los diagramas se ven borrosos
- Asegúrate de exportar en alta resolución (1200px mínimo)
- No comprimas demasiado las imágenes
- Usa formato PNG para diagramas

### El artículo se ve mal en móvil
- Verifica que uses bloques de Gutenberg (no HTML antiguo)
- Revisa el tema que usas (algunos no son responsive)
- Prueba con otro tema temporalmente

---

## 📞 Recursos de Ayuda

- **Documentación WordPress:** https://wordpress.org/support/
- **Documentación Hostinger:** https://www.hostinger.es/tutoriales
- **Soporte Hostinger:** Desde el panel de control

---

**¿Listo para publicar?** Sigue el checklist y tu artículo quedará perfecto. 🚀


