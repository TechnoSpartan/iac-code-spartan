# Changelog

All notable changes to the CodeSpartan Mambo Cloud infrastructure will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
