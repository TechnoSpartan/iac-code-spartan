# Redmine Plugins

Plugins are baked into the Docker image via `Dockerfile`. To add or remove a plugin, edit the Dockerfile and push — GitHub Actions rebuilds the image and redeploys automatically.

## Plugins instalados

### view_customize (294★)
**Repo:** https://github.com/onozaty/redmine-view-customize  
**Función:** Inyecta CSS, JavaScript y HTML personalizados en cualquier página de Redmine, filtrable por ruta URL. Sin tocar código.

**Configuración:**
1. `Administración → View customize → New`
2. Selecciona tipo (`CSS`, `JavaScript` o `HTML`)
3. Define el path donde aplica (o déjalo vacío para global)
4. Escribe el código y guarda

---

### redmine_discord (24★)
**Repo:** https://github.com/kory33/redmine_discord  
**Función:** Envía notificaciones a canales de Discord vía webhook cuando se crean, modifican o cierran issues.

**Configuración inicial (una sola vez):**
1. `Administración → Campos personalizados → Nuevo campo`
   - Aplica a: **Proyecto**
   - Formato: **Lista**
   - Nombre: `Discord Webhooks` (sensible a mayúsculas, exactamente así)
   - Marcar **"Múltiples valores"**
   - Guardar

**Por proyecto:**
1. En Discord: canal → `Editar canal → Integraciones → Webhooks → Crear webhook → Copiar URL`
2. En Redmine: Proyecto → `Configuración → Campos personalizados`
3. Pegar la URL del webhook en el campo `Discord Webhooks`

---

### redmine_dashboard (452★) — instalado ago 2026
**Repo:** https://github.com/jgraichen/redmine_dashboard  
**Función:** Tablero kanban drag & drop con filtros por proyecto. Equivalente a GitHub Projects para el día a día.

**Uso:**
1. Entrar a un proyecto
2. Menú → **Dashboard** (nueva pestaña)
3. Configurar columnas por estado del workflow
4. Drag & drop de issues entre columnas

**Estados sugeridos (CodeSpartan-Ops):** Backlog → This week → In progress → Blocked → Done

---

### clipboard_image_paste (267★) — instalado ago 2026
**Repo:** https://github.com/peclik/clipboard_image_paste  
**Función:** Pegar screenshots desde el portapapeles directamente en la descripción o notas de un issue. Útil para Angela y para adjuntar evidencia visual sin salir de Redmine.

**Uso:** Ctrl+V (o Cmd+V) en el campo de texto de un issue.

---

## Plugins pendientes (requieren compra)

| Plugin | Precio | URL |
|--------|--------|-----|
| at_checklist | €49 | https://redmine-plugins.atori.de/en/checklist.html |
| at_rechnungstellung | €449 | https://redmine-plugins.atori.de/en/rechnungstellung.html |

**Para instalarlos tras la compra:**
1. Descarga el ZIP y descomprímelo en `plugins/at_<nombre>/`
2. Descomenta la línea `COPY` correspondiente en el `Dockerfile`
3. Haz commit y push — el workflow reconstruye automáticamente

---

## Otros plugins recomendados (gratuitos, no instalados aún)

| Plugin | ★ | Qué hace |
|--------|---|----------|
| [redmine_ckeditor](https://github.com/a-ono/redmine_ckeditor) | 304★ | Editor WYSIWYG rico en lugar de Textile |
| [redmine_knowledgebase](https://github.com/alexbevi/redmine_knowledgebase) | 466★ | Base de conocimiento / wiki avanzada |
| [redmine_time_tracker](https://github.com/fernandokosh/redmine_time_tracker) | 204★ | Timer play/stop para registrar tiempo real |
| [redmine_github_hook](https://github.com/koppen/redmine_github_hook) | 483★ | Actualiza issues al hacer push a GitHub |

Para añadir cualquiera: agregar `RUN git clone --depth=1 <url> plugins/<nombre>` en el `Dockerfile` y hacer push.

---

## Cómo funciona el despliegue

### Flujo automático (CI/CD)

```
git push → GitHub Actions → SCP al VPS → docker compose build → docker compose up -d
```

El workflow `.github/workflows/deploy-redmine.yml` se activa en cada push a `codespartan/apps/codespartan-cloud/redmine/**`.

### Pasos del workflow

1. Copia todos los archivos al VPS vía SCP
2. `docker compose pull db` — actualiza imagen de PostgreSQL
3. `docker compose build app` — reconstruye imagen con plugins (puede tardar 3-5 min la primera vez)
4. `docker compose down && docker compose up -d` — redespliega

### Despliegue manual desde el VPS

```bash
ssh leonidas@91.98.137.217
cd /opt/codespartan/apps/codespartan-cloud/redmine

# Reconstruir imagen y redesplegar
docker compose build app
docker compose down
docker compose up -d

# Ver logs en tiempo real
docker logs redmine-app -f
```

### Primer despliegue (base de datos nueva)

El arranque tarda ~5 minutos porque Redmine ejecuta las migraciones de base de datos. El healthcheck tiene `start_period: 300s` para esto.

```bash
# Verificar que arrancó correctamente
docker ps | grep redmine
docker logs redmine-app --tail 50
```

---

## Arquitectura de plugins

Los plugins van **dentro de la imagen Docker** (no en volúmenes), lo que garantiza reproducibilidad:

```
Dockerfile
  └── FROM redmine:6-alpine
       ├── git clone view_customize    → plugins/view_customize/
       ├── git clone redmine_discord   → plugins/redmine_discord/
       └── bundle install              → gems de los plugins
```

El volumen `redmine-data` persiste los archivos subidos por usuarios.  
El volumen `redmine-themes` persiste los temas instalados manualmente.  
Los plugins se gestionan exclusivamente desde el `Dockerfile`.
