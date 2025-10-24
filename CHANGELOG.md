# Changelog

All notable changes to the CodeSpartan Mambo Cloud infrastructure will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.9.0] - 2025-10-19

### Changed
- **Alertmanager & Node Exporter Updates** (FASE 4):
  - Alertmanager: v0.27.0 → v0.28.1
  - Node Exporter: v1.8.2 → v1.9.1
  - Both updates include internal logging system migration to log/slog
  - No breaking changes in configuration or functionality

### Fixed
- **IPv4/IPv6 healthcheck issues**:
  - Fixed vmagent healthcheck (localhost → 127.0.0.1)
  - Fixed vmalert healthcheck (localhost → 127.0.0.1)
  - Resolved containers showing "unhealthy" status despite functioning correctly
  - All VictoriaMetrics stack components now report "healthy" status

### Technical Details

**Alertmanager v0.28.1**:
- New integrations available: Microsoft Teams (Flows), Rocket.Chat, Jira
- Improved template functions (since, humanizeDuration, date, tz)
- Support for silences limits and GOMEMLIMIT/GOMAXPROCS configuration
- Current configuration unaffected (using ntfy-forwarder webhook)

**Node Exporter v1.9.1**:
- Performance improvements in Linux filesystem collector
- Enhanced platform support (NetBSD, AIX)
- Deprecated collectors (NTP, Supervisord) not in use
- All metrics collection verified and operational

## [1.8.0] - 2025-10-18

### Changed
- **Loki/Promtail Update** (FASE 3A):
  - Loki: 2.9.0 → 3.2.1
  - Promtail: 2.9.0 → 3.2.1
  - Migrated from boltdb-shipper + v11 schema to TSDB + v13 schema
  - Maintained historical data compatibility with dual schema periods
  - Enabled structured metadata support

- **Traefik Update** (FASE 3B):
  - Traefik: v2.11 → v3.2
  - Added `--core.defaultRuleSyntax=v2` for backward compatibility
  - All Docker labels remain compatible with v2 syntax
  - Zero downtime migration achieved

### Fixed
- **Grafana datasource backward compatibility**:
  - Removed `deleteDatasources` directive that was deleting Prometheus datasource on restart
  - Added "Prometheus" datasource (UID: Prometheus) pointing to VictoriaMetrics
  - Enables legacy dashboards expecting "Prometheus" UID to work alongside new VictoriaMetrics datasource

- **VictoriaMetrics healthcheck IPv4/IPv6 issue**:
  - Changed healthcheck URL from `localhost` to `127.0.0.1`
  - Resolved container showing "unhealthy" due to IPv6 resolution
  - VictoriaMetrics listens on IPv4 0.0.0.0:8428, but `localhost` was resolving to IPv6 [::1]

### Known Issues
- Some pre-existing Grafana dashboards require reconfiguration:
  - Docker monitoring dashboard: panels have null datasource/targets
  - Prometheus Stats dashboard: queries for non-existent `job="prometheus"`
  - VictoriaMetrics dashboard: panels have null datasource/targets
- Dashboard troubleshooting postponed for future work session

### Technical Details

**Loki 3.2 Migration**:
- Added new schema period (2025-10-18) with TSDB + v13
- Preserved historical data with boltdb-shipper + v11 (2023-01-01)
- Removed deprecated `shared_store` from compactor
- Added `delete_request_store: filesystem` configuration
- Removed deprecated `max_look_back_period` from chunk_store_config
- Verified log ingestion from 18 containers

**Traefik v3 Migration**:
- Backward compatible upgrade using core.defaultRuleSyntax=v2
- All existing routing rules work without modification
- Verified access to critical services:
  - Grafana (302 redirect)
  - Backoffice (401 auth)
  - Traefik Dashboard (401 auth)

## [1.7.0] - 2025-10-18

### Changed
- **Grafana Update** (FASE 2):
  - Grafana: 10.4.5 → 11.3.1
  - Major version upgrade with new features:
    - Scenes-powered dashboards (GA)
    - Explore Logs plugin auto-installed
    - Enhanced performance and security

### Fixed
- Traefik middleware configuration issue
  - Removed invalid `tcp: {}` standalone element from dynamic-config.yml
  - Fixed "middleware does not exist" errors for all services
  - Restored access to Grafana, Backoffice, and Traefik dashboard

### Technical Details
- All datasources verified working (VictoriaMetrics, Loki)
- 9 dashboards successfully migrated and functional
- No breaking changes affecting current configuration
- AngularJS plugins not used, no compatibility issues

## [1.6.0] - 2025-10-17

### Added
- Discord webhook integration to alerting system via ntfy-forwarder
- Current Versions table in monitoring/README.md for quick reference

### Changed
- **VictoriaMetrics Stack Updates** (FASE 1):
  - VictoriaMetrics: v1.93.0 → v1.106.1
  - vmagent: v1.93.0 → v1.106.1
  - vmalert: v1.93.0 → v1.106.1
  - cAdvisor: v0.47.2 → v0.50.0
- Removed obsolete `version:` declaration from all 10 docker-compose.yml files
  - Docker Compose v2+ no longer requires version specification
  - Modernizes configuration syntax across entire infrastructure

### Fixed
- cadvisor metrics size issue (reduced from ~28MB to ~180KB)
  - Added metric filtering via `--disable_metrics` flag
  - Prevents ServiceDown alerts caused by scrape size exceeding limits
  - 99.4% reduction in metrics payload size

### Technical Details
- All updates deployed successfully without downtime
- Metrics collection verified and operational
- Backward compatible changes (no breaking configuration changes)

## [1.5.0] - 2025-10-16

### Added
- Complete monitoring stack with Discord alerting
- ntfy.sh push notification integration
- Comprehensive alert rules for system health monitoring

### Changed
- Enhanced cadvisor configuration for optimized metrics collection

## Earlier Versions

See git history for changes prior to v1.5.0.

---

**Maintainer**: DevOps Team
**Repository**: https://github.com/TechnoSpartan/iac-code-spartan
