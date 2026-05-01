#!/usr/bin/env bash
# Export Voronoi tessellation and context data to a single GeoPackage
set -euo pipefail

OUTPUT="${1:?Error: Missing output GeoPackage path}"
POSTGRES="PG:host=postgis user=postgres dbname=postgres"

# Export first layer with -overwrite (already in lat/lon)
# Add random color_id (0-11) for paired.cpt categorical coloring
ogr2ogr -f GPKG \
    -overwrite \
    -nln data_analysis.ports_voronoi \
    -sql "SELECT *, FLOOR(random()*12)::INTEGER as color_id FROM data_analysis.ports_voronoi" \
    "$OUTPUT" \
    "$POSTGRES"

# Export subsequent layers with -update and -append
# Ports are already in lat/lon, no reprojection needed
ogr2ogr -f GPKG \
    -update \
    -append \
    "$OUTPUT" \
    "$POSTGRES" \
    context_data.ports

# Coastline: reproject to lat/lon, then clip using -clipsrc with Brittany bounds
TMP_GPKG=$(mktemp).gpkg
ogr2ogr -f GPKG -t_srs EPSG:4326 "$TMP_GPKG" "$POSTGRES" context_data.europe_coastline_polygon
ogr2ogr -f GPKG \
    -update \
    -append \
    -clipsrc -6 47 -1 49 \
    "$OUTPUT" \
    "$TMP_GPKG"
rm -f "$TMP_GPKG"

echo "✓ Exported to $OUTPUT"
