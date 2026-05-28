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

# Coastline: clip OSM land polygons to Brittany bounds
ogr2ogr -f GPKG \
    -update \
    -append \
    -nln context_data.europe_coastline_polygon \
    -clipsrc -6 47 -1 49 \
    "$OUTPUT" \
    "/workdir/data/processed/osm_land_polygons/land_polygons.shp"

echo "✓ Exported to $OUTPUT"
