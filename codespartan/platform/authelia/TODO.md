# Authelia Configuration TODOs

## Warnings Addressed (v5 Migration Complete)

> **Status**: COMPLETED (2026-01-08)
> **Target**: Authelia v5.0.0 compatible

### Server Configuration
- [x] Replace `server.host`, `server.port`, `server.path` with `server.address`
  - New format: `tcp://0.0.0.0:9091/`

- [x] Replace `server.enable_pprof` with `server.endpoints.enable_pprof`
- [x] Replace `server.enable_expvars` with `server.endpoints.enable_expvars`

### OIDC Configuration
- [x] Replace `identity_providers.oidc.access_token_lifespan` with `identity_providers.oidc.lifespans.access_token`
- [x] Replace `identity_providers.oidc.id_token_lifespan` with `identity_providers.oidc.lifespans.id_token`
- [x] Replace `identity_providers.oidc.refresh_token_lifespan` with `identity_providers.oidc.lifespans.refresh_token`
- [x] Replace `identity_providers.oidc.authorize_code_lifespan` with `identity_providers.oidc.lifespans.authorize_code`

### OIDC Clients (Grafana)
- [x] Replace `clients[].id` with `clients[].client_id`
- [x] Replace `clients[].secret` with `clients[].client_secret`
- [x] Replace `clients[].description` with `clients[].client_name`
- [x] Replace `clients[].userinfo_signing_algorithm` with `clients[].userinfo_signed_response_alg`
- [ ] Hash `client_secret` value (optional security improvement)

### Session Configuration
- [x] Replace single `session.domain` with multi-domain `session.cookies` configuration
- [x] Replace `session.remember_me_duration` with `session.remember_me`

### WebAuthn Configuration
- [x] Replace `webauthn.user_verification` with `webauthn.selection_criteria.user_verification`

## Security Improvements (Optional)
- [ ] Hash Grafana OAuth2 client_secret (currently plaintext)
  - Current: `tBVp0E9iP9KDuaR/JbjHT6QpV4+yWiirtjdSzFCEzUs=`
  - Use: `authelia crypto hash generate pbkdf2` or `authelia crypto hash generate argon2`

## Reference
- Authelia v4.38.0 deprecation warnings - RESOLVED
- Configuration now compatible with Authelia v5.0.0
- Updated: 2026-01-08
