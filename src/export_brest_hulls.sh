#!/usr/bin/env bash
# Export cluster convex hulls and centroids to a standalone GeoPackage for Brest
set -euo pipefail

OUTPUT="${1:?Error: Missing output GeoPackage path}"
POSTGRES="PG:host=postgis user=postgres dbname=postgres"

# Convex hulls with cluster color for categorical coloring
ogr2ogr -f GPKG \
    -overwrite \
    -nln data_analysis.clusters_stops_hulls \
    -sql "SELECT cid, cid % 25 AS z, ST_Transform(convex_hull, 4326) AS geom FROM data_analysis.clusters_stops_hulls" \
    "$OUTPUT" \
    "$POSTGRES"

# Centroids with same cluster color
ogr2ogr -f GPKG \
    -update \
    -append \
    -nln data_analysis.clusters_stops_hulls_centroids \
    -sql "SELECT cid, cid % 25 AS z, ST_Transform(centroid, 4326) AS geom FROM data_analysis.clusters_stops_hulls" \
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
