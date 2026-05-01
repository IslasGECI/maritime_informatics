#!/usr/bin/env bash
# Plot Voronoi tessellation using GMT 6 with auto-calculated region
set -euo pipefail

INPUT="${1:-data/processed/maritime_context.gpkg}"
OUTPUT="${2:-reports/figures/voronoi_map.png}"

# Create parent directory
mkdir --parents "$(dirname "$OUTPUT")"

# Extract layers to temporary shapefiles for GMT
TMPDIR="/tmp/gmt_voronoi_$$"
mkdir --parents "$TMPDIR"
trap "rm --force --recursive $TMPDIR" EXIT

# All layers are now in lat/lon (EPSG:4326) in the GeoPackage
ogr2ogr -f "ESRI Shapefile" -nln coastline "$TMPDIR" "$INPUT" "context_data.europe_coastline_polygon"
ogr2ogr -f "ESRI Shapefile" -nln voronoi "$TMPDIR" "$INPUT" "data_analysis.ports_voronoi"
ogr2ogr -f "ESRI Shapefile" -nln ports "$TMPDIR" "$INPUT" "context_data.ports"

# Brittany region in lat/lon (degrees)
REGION="-6/-1/47/49"

gmt begin "voronoi_map" png
    gmt basemap \
        -R"$REGION" \
        -JQ15c \
        -Baf \
        -B+t"Voronoi Tessellation - Brittany Ports"
    
    # Voronoi polygons (bottom layer) - fill by random color_id, black outline
    gmt plot "$TMPDIR/voronoi.shp" \
        -L \
        -aZ=color_id \
        -C/usr/share/gmt/cpt/paired.cpt \
        -W0.25p,black
    
    # Coastline (middle layer) - translucent gray land
    gmt plot "$TMPDIR/coastline.shp" \
        -Ggray \
        -W0.5p,black \
        -t10
    
    # Port points (top layer)
    gmt plot "$TMPDIR/ports.shp" \
        -Sc0.15c \
        -Gred \
        -W0.25p,black
gmt end

# Move output to desired location
mv voronoi_map.png "$OUTPUT"
echo "✓ Generated $OUTPUT"
