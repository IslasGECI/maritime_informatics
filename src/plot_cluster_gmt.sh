#!/usr/bin/env bash
# Plot cluster stops using GMT 6
set -euo pipefail

INPUT="${1:?Error: Missing input GeoPackage path}"
OUTPUT="${2:?Error: Missing output PNG path}"

TMP_DIR="/tmp/gmt_cluster_$$"
mkdir --parents "$TMP_DIR"
trap "rm --force --recursive $TMP_DIR" EXIT

# Coastline: shapefile works for polygons
ogr2ogr -f "ESRI Shapefile" -nln coastline "$TMP_DIR" "$INPUT" "context_data.europe_coastline_polygon"

# Point layers: CSV with GEOMETRY=AS_XY avoids GMT 6.3.0 OGR shapefile bug
# where -aZ=color_id silently fails to map attributes.
ogr2ogr -f CSV "$TMP_DIR/clusters.csv" "$INPUT" data_analysis.cluster_stops -lco GEOMETRY=AS_XY
ogr2ogr -f CSV "$TMP_DIR/noise.csv" "$INPUT" data_analysis.cluster_stops_noise -lco GEOMETRY=AS_XY

REGION="-4.5/-4.425/48.371667/48.400556"

gmt begin "cluster_map" png
    gmt basemap \
        -R"$REGION" \
        -JM15c \
        -Baf \
        -B+t"Stop Clusters - Port of Brest"

    # Coastline (bottom layer) - translucent gray
    gmt plot "$TMP_DIR/coastline.shp" \
        -Ggray \
        -W0.5p,black \
        -t10

    # Noise points (middle layer) - small gray transparent dots
    # CSV columns: X, Y
    gmt plot "$TMP_DIR/noise.csv" \
        -i0,1 \
        -Sc0.05c \
        -Ggray \
        -t50

    # Cluster stops (top layer) - colored by cluster ID
    # CSV columns: X, Y, cid, z  →  col 3 = z value (cid % 25) for CPT lookup
    gmt plot "$TMP_DIR/clusters.csv" \
        -i0,1,3 \
        -Sc0.15c \
        -W0.25p,black \
        -C/usr/share/gmt/cpt/categorical.cpt
gmt end

mv cluster_map.png "$OUTPUT"
echo "✓ Generated $OUTPUT"
