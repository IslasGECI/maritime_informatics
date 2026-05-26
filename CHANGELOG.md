# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-26

### Added

- AIS dynamic position data pipeline with `make init_vessel` importing 19
  million position records into `ais_data.dynamic_ships`
- Vessel segments computation via `make compute_vessel_segments`, creating
  consecutive position pairs per vessel in `data_analysis.segments`
- `data_analysis` schema now includes `segments` table for vessel stop
  detection and speed analysis

### Changed

- `make init_db` split into three single-responsibility targets:
  `init_database`, `init_port`, and `init_coastline`
- Context data initialization targets now use `DROP TABLE IF EXISTS` for
  idempotency instead of cascading schema drops

### Removed

- All R-related code, tests, package metadata, and documentation. The project
  now uses GMT for plotting instead of R.
- Composite `make init_db` target removed; use `make init_database`,
  `make init_port`, and `make init_coastline` individually

[unreleased]: https://github.com/IslasGECI/maritime_informatics/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/IslasGECI/maritime_informatics/releases/tag/v0.1.0
