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
|---|---|---|
| `data_analysis.ports_voronoi` | Voronoi tessellation polygons around each port | 222 |
| `data_analysis.segments` | Consecutive position pairs per vessel from AIS data | 19030575 |

Columns:
- `mmsi` — Ship identifier
- `t1`, `t2` — Starting and ending Unix epoch timestamps
- `speed1`, `speed2` — Starting and ending speeds (SOG)
- `p1`, `p2` — Starting and ending points (EPSG:3035)
- `segment` — Line connecting `p1` to `p2`
- `distance` — Distance between consecutive points (meters)
- `duration_s` — Time difference in seconds
- `speed_m_s` — Speed derived from distance/duration (m/s)
