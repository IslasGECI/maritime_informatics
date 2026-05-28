#!/usr/bin/env bash
# Plot cluster convex hulls and centroid stars using GMT 6
set -euo pipefail

INPUT="${1:?Error: Missing input GeoPackage path}"
OUTPUT="${2:?Error: Missing output PNG path}"

TMP_DIR="/tmp/gmt_hulls_$$"
mkdir --parents "$TMP_DIR"
trap "rm --force --recursive $TMP_DIR" EXIT

# Coastline: shapefile works for polygons
ogr2ogr -f "ESRI Shapefile" -nln coastline "$TMP_DIR" "$INPUT" "context_data.europe_coastline_polygon"

# Convex hulls: shapefile works for polygons (the -aZ bug only affects point shapefiles)
ogr2ogr -f "ESRI Shapefile" -nln hulls "$TMP_DIR" "$INPUT" "data_analysis.clusters_stops_hulls"

# Centroids: CSV with GEOMETRY=AS_XY avoids GMT 6.3.0 OGR shapefile bug for points
ogr2ogr -f CSV "$TMP_DIR/centroids.csv" "$INPUT" data_analysis.clusters_stops_hulls_centroids -lco GEOMETRY=AS_XY

REGION="-4.5/-4.425/48.371667/48.400556"

gmt begin "brest_hulls" png
    gmt basemap \
        -R"$REGION" \
        -JM15c \
        -Baf \
        -B+t"Convex Hulls - Port of Brest"

    # Coastline (bottom layer) - translucent gray
    gmt plot "$TMP_DIR/coastline.shp" \
        -Ggray \
        -W0.5p,black \
        -t10

    # Convex hulls (middle layer) - filled by cluster color, no outline
    # Shapefile with -aZ=z works for polygon geometries (bug only affects point shapefiles)
    gmt plot "$TMP_DIR/hulls.shp" \
        -aZ=z \
        -G+z \
        -C/usr/share/gmt/cpt/categorical.cpt

    # Centroid stars (top layer) - colored by cluster, black outline
    # CSV columns: X, Y, cid, z  →  col 3 = z value for CPT lookup
    gmt plot "$TMP_DIR/centroids.csv" \
        -i0,1,3 \
        -Sa0.2c \
        -W0.25p,black \
        -C/usr/share/gmt/cpt/categorical.cpt
gmt end

mv brest_hulls.png "$OUTPUT"
echo "✓ Generated $OUTPUT"
