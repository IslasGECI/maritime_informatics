# Technical Reference

## Makefile Targets

### make all

Build the complete Voronoi tessellation map. Default target.

- Depends on: `reports/figures/voronoi_map.png`

### make clean

Remove all generated data and external archives.

- Removes: `data/processed/` and `data/external/`

### make init_database

Create the `context_data` schema if it does not exist.

- Notes: Safe to run multiple times. Does not import any data.

### make init_port

Import the Brittany ports shapefile into `context_data.ports`.

- Dependencies: `init_database`
- Data source: `data/external/[C1] Ports of Brittany.zip`
- Table: `context_data.ports`
- Rows expected: 222
- Notes: The shapefile `.prj` file is mislabeled as WGS84 (EPSG:4326). Actual coordinates are EPSG:3035. Import uses SRID 3035.

### make init_coastline

Import the European coastline polygon shapefile into `context_data.europe_coastline_polygon`.

- Dependencies: `init_database`
- Data source: `data/external/[C2] European Coastline.zip`
- Table: `context_data.europe_coastline_polygon`
- Rows expected: 71514

### make init_vessel

Import AIS dynamic vessel position data into `ais_data.dynamic_ships`.

- Dependencies: none
- Data source: `data/external/[P1] AIS Data.zip` → `nari_dynamic.csv`
- Table: `ais_data.dynamic_ships`
- Rows expected: 19035630
- Notes: Raw CSV lon/lat (EPSG:4326) coordinates are transformed to EPSG:3035 geometry during import. Alias columns (`mmsi`, `speed`) are populated from CSV originals.

### make compute_vessel_segments

Build the vessel segments table from consecutive AIS position pairs.

- Dependencies: `init_vessel`
- Table created: `data_analysis.segments`
- Uses `LEAD` window function ordered by `(mmsi, t)` to pair consecutive positions per vessel

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

### data_analysis

Derived analytical outputs.

| Table | Description | Rows |
|---|---|---|
| `data_analysis.ports_voronoi` | Voronoi tessellation polygons around each port | 222 |
| `data_analysis.segments` | Consecutive position pairs per vessel from AIS data | — |
