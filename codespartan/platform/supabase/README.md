# Supabase self-hosted

Stack completo de Supabase (11 servicios) corriendo en el VPS `CodeSpartan-apis`
(cx33, x86, aislado del VPS ARM). No hay Traefik en este host: Kong publica su
puerto 8000 solo en la IP privada `10.0.0.3` (red `codespartan-internal`,
`10.0.0.0/24`). Traefik en el VPS ARM termina TLS para `api.cyberdyne-systems.es`
y reenvia en HTTP plano a esa IP privada — ver
`codespartan/platform/traefik/dynamic-config.yml`. El Cloud Firewall de Hetzner
no permite el puerto 8000 en la IP publica, y las redes privadas de Hetzner no
pasan por internet.

## Arquitectura

```
Internet -> Traefik (VPS ARM, TLS) -> [red privada 10.0.0.0/24] -> Kong:8000 (VPS APIs)
                                                                      |
                                        auth / rest / realtime / storage / functions / meta
                                                                      |
                                                                     db (Postgres 17)
```

## Despliegue

Via `.github/workflows/deploy-supabase.yml`: hace `envsubst` de `.env.example`
con los GitHub Secrets `SUPABASE_*` + `OPENROUTER_API_KEY`, copia todo a
`/opt/codespartan/platform/supabase/` en el VPS de APIs, `docker compose up -d`,
espera a que los 11 contenedores esten `healthy`, aplica las migraciones SQL de
`ft-rc-bko-social_posts/supabase/migrations/` y despliega las Edge Functions.

## Acceso admin (Studio)

Kong enruta `/` (catch-all) a Supabase Studio protegido con basic auth:
`https://api.cyberdyne-systems.es/` con las credenciales de los secrets
`SUPABASE_DASHBOARD_USERNAME` / `SUPABASE_DASHBOARD_PASSWORD`.

## Notas de seguridad

- `DISABLE_SIGNUP=true`: el `ANON_KEY` va embebido en el frontend (no es
  secreto), asi que el autoregistro publico via `/auth/v1/signup` esta
  desactivado. Los usuarios admin se crean a mano via la API de GoTrue con el
  `SERVICE_ROLE_KEY`.
- `supavisor` (pooler) no publica ningun puerto: nada en este proyecto necesita
  conexion directa a Postgres, todo pasa por PostgREST/Kong.
- Solo se usa el modelo de claves legacy HS256 (`ANON_KEY`/`SERVICE_ROLE_KEY`);
  el modelo nuevo de claves opacas (`sb_*`) se deja sin configurar.

## Secrets requeridos (GitHub, repo `iac-code-spartan`)

`SUPABASE_POSTGRES_PASSWORD`, `SUPABASE_JWT_SECRET`, `SUPABASE_ANON_KEY`,
`SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DASHBOARD_USERNAME`,
`SUPABASE_DASHBOARD_PASSWORD`, `SUPABASE_SECRET_KEY_BASE`,
`SUPABASE_VAULT_ENC_KEY`, `SUPABASE_PG_META_CRYPTO_KEY`,
`SUPABASE_REALTIME_DB_ENC_KEY`, `SUPABASE_SMTP_HOST`, `SUPABASE_SMTP_PORT`,
`SUPABASE_SMTP_USER`, `SUPABASE_SMTP_PASS`, `SUPABASE_SMTP_ADMIN_EMAIL`,
`SUPABASE_SMTP_SENDER_NAME`, `OPENROUTER_API_KEY`.
