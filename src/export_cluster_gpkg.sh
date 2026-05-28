#!/usr/bin/env bash
# Export cluster stops and context data to a standalone GeoPackage
set -euo pipefail

OUTPUT="${1:?Error: Missing output GeoPackage path}"
POSTGRES="PG:host=postgis user=postgres dbname=postgres"

# Clustered stops with color_id for categorical coloring (cid % 25 matches categorical.cpt 0-24)
ogr2ogr -f GPKG \
    -overwrite \
    -nln data_analysis.cluster_stops \
    -sql "SELECT cid, cid % 25 AS z, ST_Transform(centr3035, 4326) AS geom FROM data_analysis.cluster_stops WHERE cid IS NOT NULL" \
    "$OUTPUT" \
    "$POSTGRES"

# Noise points (unclustered stops) - plotted as small gray transparent dots
ogr2ogr -f GPKG \
    -update \
    -append \
    -nln data_analysis.cluster_stops_noise \
    -sql "SELECT ST_Transform(centr3035, 4326) AS geom FROM data_analysis.cluster_stops WHERE cid IS NULL" \
    "$OUTPUT" \
    "$POSTGRES"

# Coastline: reproject to lat/lon, clip to Brest bounds
TMP_GPKG=$(mktemp).gpkg
ogr2ogr -f GPKG -t_srs EPSG:4326 "$TMP_GPKG" "$POSTGRES" context_data.europe_coastline_polygon
ogr2ogr -f GPKG \
    -update \
    -append \
    -nln context_data.europe_coastline_polygon \
    -clipsrc -4.5 48.371667 -4.425 48.400556 \
    "$OUTPUT" \
    "$TMP_GPKG"
rm -f "$TMP_GPKG"

echo "✓ Exported to $OUTPUT"
