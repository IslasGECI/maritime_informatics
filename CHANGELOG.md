# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Stamp file targets (`data/processed/.<schema>.<table>.stamp`) for database state
  tracking, enabling Make to skip already-completed database imports and computations
- File targets for zip extraction (`data/external/port.shp`, `nari_dynamic.csv`)
  so Make only unzips when the target file is missing
- Index `idx_dynamic_ships_t` on `ais_data.dynamic_ships(t)` for timestamp-range queries
- Row count assertions on `data_analysis.segments` (19030575 rows)
- Stop-detection auxiliary tables (`data_analysis.stop_begin`, `data_analysis.stop_end`)
  computed from vessel segments using a 0.1 kn speed threshold, with indexes on
  `(mmsi, t_begin)` and `(mmsi, t_end)` respectively
- Consolidated stops table (`data_analysis.stops`) built by coupling stop_begin and
  stop_end events per vessel via lateral join, with event duration
- Enriched stops with centroid geometry (`centr3035`) and position count (`nb_pos`)
  computed from raw AIS data within each stop's timestamp range
- Enriched stops with average and maximum distance from centroid (`avg_dist_centroid`,
  `max_dist_centroid`) as dispersion indicators for characterising stop nature
- DBSCAN clustering of stop centroids into `data_analysis.cluster_stops` with
  eps=50 m, minpoints=5, yielding 353 stationary-area clusters
- Cluster map export (`data/processed/cluster_map.gpkg`) and GMT rendering
  (`reports/figures/cluster_map.png`) for the Port of Brest, wired into
  `make all`

### Changed

- `init_port`, `init_coastline`, `init_vessel`, `compute_vessel_segments`, and
  `init_database` replaced by stamp-based file targets
- Extraction file targets no longer depend on the zip archive as a Make prerequisite —
  the recipe runs only when the target file does not exist; `touch $@` added after
  extraction to prevent timestamp-triggered rebuilds
- Coasline extraction moved inline into the stamp recipe (the shapefile path
  contains spaces and parentheses, which break Make automatic variables)
- `idx_dynamic_ships_mmsi_t` moved from `compute_vessel_segments.sql` into
  `init_ais_dynamic_ships.sql` (created table-side, not query-side)
- `compute_vessel_segments.sql` now uses `DROP TABLE IF EXISTS ... CASCADE` for
  idempotent re-runs without errors
- `reports/figures/voronoi_map.png` no longer waits for the full AIS pipeline —
  only port, coastline, and Voronoi computations are needed

### Removed

- All intermediate phony targets: `init_database`, `init_port`, `init_coastline`,
  `init_vessel`, `compute_vessel_segments`

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
