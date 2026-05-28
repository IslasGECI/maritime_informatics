# Technical Reference

## Makefile Targets

### make all

Build the complete Voronoi tessellation map. Default target.

- Depends on: `reports/figures/voronoi_map.png`

### make clean

Remove all generated data and external archives.

- Removes: `data/processed/` and `data/external/`

### make data/external/port.shp

Extract port shapefile from zip.

- Data source: `data/external/[C1] Ports of Brittany.zip`

### make data/external/nari_dynamic.csv

Extract AIS CSV from zip.

- Data source: `data/external/[P1] AIS Data.zip`

### make data/processed/.context_data.ports.stamp

Import the Brittany ports shapefile into `context_data.ports`.

- Dependencies: `data/external/port.shp`
- Table: `context_data.ports`
- Rows expected: 222
- Notes: The shapefile `.prj` file is mislabeled as WGS84 (EPSG:4326). Actual coordinates are EPSG:3035. Import uses SRID 3035.

### make data/processed/.context_data.europe_coastline_polygon.stamp

Import the European coastline polygon shapefile into `context_data.europe_coastline_polygon`.

- Dependencies: none (extracts from zip inline)
- Data source: `data/external/[C2] European Coastline.zip`
- Table: `context_data.europe_coastline_polygon`
- Rows expected: 71514

### make data/processed/.ais_data.dynamic_ships.stamp

Import AIS dynamic vessel position data into `ais_data.dynamic_ships`.

- Dependencies: `data/external/nari_dynamic.csv`
- Table: `ais_data.dynamic_ships`
- Rows expected: 19035630
- Notes: Raw CSV lon/lat (EPSG:4326) coordinates are transformed to EPSG:3035 geometry during import. Alias columns (`mmsi`, `speed`) are populated from CSV originals.

### make data/processed/.data_analysis.segments.stamp

Build the vessel segments table from consecutive AIS position pairs.

- Dependencies: `data/processed/.ais_data.dynamic_ships.stamp`
- Table created: `data_analysis.segments`
- Rows expected: 19030575
- Uses `LEAD` window function ordered by `(mmsi, t)` to pair consecutive positions per vessel

### make data/processed/.data_analysis.stop_tables.stamp

Build auxiliary stop-detection tables (`stop_begin`, `stop_end`) from vessel segments.

- Dependencies: `data/processed/.data_analysis.segments.stamp`
- Tables created: `data_analysis.stop_begin`, `data_analysis.stop_end`
- Uses a speed threshold of 0.1 kn to detect transitions between moving and stopped states
- `stop_begin` captures segments that go from moving (speed1 > 0.1) to stopped (speed2 ≤ 0.1)
- `stop_end` captures segments that go from stopped (speed1 ≤ 0.1) to moving (speed2 > 0.1)

### make data/processed/.data_analysis.stops.stamp

Build the consolidated stops table by coupling stop_begin and stop_end events per vessel.

- Dependencies: `data/processed/.data_analysis.stop_tables.stamp`
- Table created: `data_analysis.stops`
- Uses an inner lateral join to pair each stop-start with the chronologically first matching stop-end for the same vessel
- Each row represents a complete stop event with start time, end time, and duration
- Enriches each stop with the centroid geometry and position count from the raw AIS data

### make data/processed/.data_analysis.cluster_stops.stamp

Cluster stop centroids using DBSCAN to detect frequent stationary areas.

- Dependencies: `data/processed/.data_analysis.stops.stamp`
- Table created: `data_analysis.cluster_stops`
- Uses `ST_ClusterDBSCAN` with `eps := 50` metres, `minpoints := 5`, considering only stops lasting at least one minute
- Each row is a stop event with an assigned cluster ID (`cid`); noise points have `cid IS NULL`
- Produces 353 distinct clusters covering mooring areas across Brittany ports

### make data/processed/.data_analysis.ports_voronoi.stamp

Compute Voronoi tessellation polygons from port locations.

- Dependencies: `data/processed/.context_data.ports.stamp`
- Table created: `data_analysis.ports_voronoi`

### make data/processed/brittany_maritime.gpkg

Export all layers to a single GeoPackage.

- Dependencies: `data/processed/.data_analysis.ports_voronoi.stamp`, `data/processed/.context_data.europe_coastline_polygon.stamp`
- Reprojects coastline to EPSG:4326, clips to Brittany bounds

### make reports/figures/voronoi_map.png

Render the Voronoi tessellation map to a PNG image.

- Dependencies: `data/processed/brittany_maritime.gpkg`
- Output: `reports/figures/voronoi_map.png`
- Uses GMT 6 to plot Voronoi polygons, coastline, and port points

### make data/processed/cluster_map.gpkg

Export cluster stops and coastline to a standalone GeoPackage for the Port of Brest area.

- Dependencies: `data/processed/.data_analysis.cluster_stops.stamp`, `data/processed/.context_data.europe_coastline_polygon.stamp`
- Layers: cluster stops (with `color_id = cid % 25`), noise points, coastline clipped to Brest bounds
- All geometries reprojected to EPSG:4326

### make reports/figures/cluster_map.png

Render the cluster stops map to a PNG image.

- Dependencies: `data/processed/cluster_map.gpkg`
- Output: `reports/figures/cluster_map.png`
- Uses GMT 6 to plot clustered stop centroids (colored by cluster ID via `categorical.cpt`), noise points (small gray transparent dots), and coastline

## Database Schemas

### context_data

Geospatial context data for the Brittany region.

| Table | Description | Rows |
|---|---|---|
| `context_data.ports` | Brittany port locations (MultiPoint, EPSG:3035) | 222 |
| `context_data.europe_coastline_polygon` | European coastline polygon (MultiPolygon, EPSG:3035) | 71514 |

### ais_data

AIS ship position records imported from CSV.

| Table | Description | Rows |
|---|---|---|
| `ais_data.dynamic_ships` | AIS dynamic position reports with transformed geometry | 19035630 |

Columns:
- `id` — bigserial, primary key
- `sourcemmsi` — MMSI identifier of the source transceiver
- `navigationalstatus` — Navigational status code
- `rateofturn` — Rate of turn
- `speedoverground` — Speed over ground (SOG)
- `courseoverground` — Course over ground (COG)
- `trueheading` — True heading
- `lon` — Longitude in decimal degrees (EPSG:4326)
- `lat` — Latitude in decimal degrees (EPSG:4326)
- `t` — Timestamp as Unix epoch (seconds)
- `mmsi` — MMSI identifier (aliased from sourcemmsi)
- `speed` — Speed over ground (aliased from speedoverground)
- `geom3035` — Point geometry in EPSG:3035

Indexes:
- `idx_dynamic_ships_mmsi_t` on `(mmsi, t)` — supports segments `LEAD` window
- `idx_dynamic_ships_t` on `(t)` — supports timestamp-range queries

### data_analysis

Derived analytical outputs.

| Table | Description | Rows |
|---|---|---|---|
| `data_analysis.ports_voronoi` | Voronoi tessellation polygons around each port | 222 |
| `data_analysis.segments` | Consecutive position pairs per vessel from AIS data | 19030575 |
| `data_analysis.stop_begin` | Potential stop-start positions: segments transitioning from moving to stopped (speed1 > 0.1, speed2 ≤ 0.1) | — |
| `data_analysis.stop_end` | Potential stop-end positions: segments transitioning from stopped to moving (speed1 ≤ 0.1, speed2 > 0.1) | — |
| `data_analysis.stops` | Consolidated stop events: stop_begin paired with the chronologically first matching stop_end per vessel | — |
| `data_analysis.cluster_stops` | DBSCAN-clustered stop events (eps=50 m, minpoints=5, duration ≥ 60 s) with cluster IDs | 55304 |

Columns (`data_analysis.segments`):
- `mmsi` — Ship identifier
- `t1`, `t2` — Starting and ending Unix epoch timestamps
- `speed1`, `speed2` — Starting and ending speeds (SOG)
- `p1`, `p2` — Starting and ending points (EPSG:3035)
- `segment` — Line connecting `p1` to `p2`
- `distance` — Distance between consecutive points (meters)
- `duration_s` — Time difference in seconds
- `speed_m_s` — Speed derived from distance/duration (m/s)

Columns (`data_analysis.stop_begin`):
- `mmsi` — Ship identifier
- `t_begin` — Timestamp of the first steady (stopped) position after deceleration

Indexes:
- `idx_stop_begin_mmsi_t` on `(mmsi, t_begin)` — supports stop-start lookups per vessel

Columns (`data_analysis.stop_end`):
- `mmsi` — Ship identifier
- `t_end` — Timestamp of the last steady (stopped) position before acceleration

Indexes:
- `idx_stop_end_mmsi_t` on `(mmsi, t_end)` — supports stop-end lookups per vessel

Columns (`data_analysis.stops`):
- `mmsi` — Ship identifier
- `t_begin` — Start of the stop event (Unix epoch seconds)
- `t_end` — End of the stop event (Unix epoch seconds)
- `duration_s` — Stop duration in seconds
- `centr3035` — Centroid point (EPSG:3035) of all AIS positions collected during the stop
- `nb_pos` — Number of AIS position reports within the stop's timestamp range
- `avg_dist_centroid` — Average distance (meters) of AIS positions from the stop centroid, indicating spatial dispersion
- `max_dist_centroid` — Maximum distance (meters) of any AIS position from the stop centroid

Columns (`data_analysis.cluster_stops`):
- All columns from `data_analysis.stops`
- `cid` — DBSCAN cluster identifier; `NULL` for noise points not assigned to any cluster
