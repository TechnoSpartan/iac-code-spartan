# Twenty CRM — codespartan.cloud

CRM comercial CodeSpartan en `https://crm.codespartan.cloud`.

## Arquitectura

| Pieza | Valor |
|-------|--------|
| Host público | `crm.codespartan.cloud` |
| Backend | VPS APIs `CodeSpartan-apis` · `10.0.0.3:3000` |
| Edge | Traefik (VPS principal) + **Authelia ForwardAuth** |
| Stack | server, worker, PostgreSQL, Redis |
| Red interna | `crm_internal` (`172.34.0.0/24`) |

```
Browser → Traefik (TLS) → Authelia MFA → twenty-server (10.0.0.3:3000)
dental-ia form → http://10.0.0.3:3000/rest/...  (private API, API key)
```

## Modelo de acceso

1. **Puerta Authelia** — solo usuarios en grupos `admins` o `dev` (MFA).
2. **Twenty** — single workspace; `IS_SIGN_UP_DISABLED=true`; miembros por **invitación**.
3. **No es SSO OIDC** Authelia→Twenty (doble login posible: Authelia + sesión Twenty).

### Añadir un compañero

1. Crear usuario en Authelia (`users_database`) con grupo `dev` o `admins`.
2. Redeploy Authelia.
3. En Twenty: **Settings → Members → Invite** con su email.
4. El usuario pasa Authelia y completa la invitación Twenty.

## API para leads (DentalFlow)

1. En Twenty: **Settings → API & Webhooks → Create key** (rol con create Company/Person/Opportunity).
2. Guardar en GitHub Secrets IaC: `TWENTY_API_KEY`.
3. dental-ia llama a `TWENTY_API_URL` (default `http://10.0.0.3:3000`), **nunca** a `https://crm...` (Authelia bloquearía).

## Deploy

```bash
gh workflow run deploy-crm.yml
# Authelia / Traefik changes:
gh workflow run deploy-authelia.yml
gh workflow run deploy-traefik.yml   # or restart-traefik
```

## Secrets

| Secret | Uso |
|--------|-----|
| `CRM_PG_PASSWORD` | Postgres Twenty |
| `CRM_ENCRYPTION_KEY` | ENCRYPTION_KEY |
| `CRM_HOSTNAME` | Opcional SERVER_URL |
| `APIS_VPS_SSH_*` | Deploy al VPS secundario |
| `TWENTY_API_KEY` | Consumido por dental-ia (secret en workflow dental) |
