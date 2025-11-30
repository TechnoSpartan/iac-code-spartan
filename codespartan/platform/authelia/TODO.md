# Authelia Configuration TODOs

## Warnings to Address (Deprecated Configuration Keys)

> **Priority**: Low (auto-mapped, no functional impact)
> **Target**: Before Authelia v5.0.0 release

### Server Configuration
- [ ] Replace `server.host`, `server.port`, `server.path` with `server.address`
  - Current: Separate host/port/path
  - New format: `tcp://0.0.0.0:9091/`

- [ ] Replace `server.enable_pprof` with `server.endpoints.enable_pprof`
- [ ] Replace `server.enable_expvars` with `server.endpoints.enable_expvars`

### OIDC Configuration
- [ ] Replace `identity_providers.oidc.access_token_lifespan` with `identity_providers.oidc.lifespans.access_token`
- [ ] Replace `identity_providers.oidc.id_token_lifespan` with `identity_providers.oidc.lifespans.id_token`
- [ ] Replace `identity_providers.oidc.refresh_token_lifespan` with `identity_providers.oidc.lifespans.refresh_token`
- [ ] Replace `identity_providers.oidc.authorize_code_lifespan` with `identity_providers.oidc.lifespans.authorize_code`

### OIDC Clients (Grafana)
- [ ] Replace `clients[].id` with `clients[].client_id`
- [ ] Replace `clients[].secret` with `clients[].client_secret`
- [ ] Replace `clients[].description` with `clients[].client_name`
- [ ] Replace `clients[].userinfo_signing_algorithm` with `clients[].userinfo_signed_response_alg`
- [ ] Hash `client_secret` value (currently plaintext)

### Session Configuration
- [ ] Replace single `session.domain` with multi-domain configuration
- [ ] Replace `session.remember_me_duration` with `session.remember_me`

### WebAuthn Configuration
- [ ] Replace `webauthn.user_verification` with `webauthn.selection_criteria.user_verification`

## Security Improvements
- [ ] Hash Grafana OAuth2 client_secret (currently plaintext)
  - Current: `tBVp0E9iP9KDuaR/JbjHT6QpV4+yWiirtjdSzFCEzUs=`
  - Use: `authelia crypto hash generate pbkdf2` or `authelia crypto hash generate argon2`

## Reference
- Authelia v4.38.0 deprecation warnings
- Auto-mapping currently handles backwards compatibility
- Must be addressed before v5.0.0 (removal of auto-mapping)
