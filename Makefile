all: reports/figures/voronoi_map.png reports/figures/cluster_map.png reports/figures/brest_hulls.png

.PHONY: all clean init

clean:
	rm --force --recursive data/external
	rm --force --recursive data/processed
	rm --force --recursive reports/figures

init:
	git config --global --add safe.directory /workdir
	git config --global user.name "Ciencia de Datos • GECI"
	git config --global user.email "ciencia.datos@islas.org.mx"

# === INPUT FILE TARGETS (extract from zips) ===

data/external/port.shp:
	unzip -o "data/external/[C1] Ports of Brittany.zip" "port.*" -d $(@D)
	touch $@

data/external/nari_dynamic.csv:
	unzip -o "data/external/[P1] AIS Data.zip" "nari_dynamic.csv" -d $(@D)
	touch $@

# === DATABASE STAMP TARGETS ===

data/processed/.context_data.ports.stamp: data/external/port.shp
	psql --host=postgis --username=postgres --command "CREATE SCHEMA IF NOT EXISTS context_data;"
	psql --host=postgis --username=postgres --command "DROP TABLE IF EXISTS context_data.ports CASCADE;"
	shp2pgsql -s 3035 -I -D "$<" context_data.ports > /tmp/ports.sql
	psql --host=postgis --username=postgres --file=/tmp/ports.sql
	psql --host=postgis --username=postgres --command "ALTER TABLE context_data.ports RENAME COLUMN geom TO geom3035;"
	psql --host=postgis --username=postgres \
	    --command "SELECT COUNT(*) FROM context_data.ports;" \
	    | grep 222
	mkdir --parents $(@D)
	touch $@

data/processed/.context_data.europe_coastline_polygon.stamp:
	psql --host=postgis --username=postgres --command "CREATE SCHEMA IF NOT EXISTS context_data;"
	psql --host=postgis --username=postgres --command "DROP TABLE IF EXISTS context_data.europe_coastline_polygon CASCADE;"
	unzip -o "data/external/[C2] European Coastline.zip" "Europe Coastline (Polygone).*" -d data/external/
	shp2pgsql -s 3035 -I -D "data/external/Europe Coastline (Polygone).shp" context_data.europe_coastline_polygon > /tmp/europe_coastline_polygon.sql
	psql --host=postgis --username=postgres --file=/tmp/europe_coastline_polygon.sql
	psql --host=postgis --username=postgres \
	    --command "SELECT COUNT(*) FROM context_data.europe_coastline_polygon;" \
	    | grep 71514
	mkdir --parents $(@D)
	touch $@

data/processed/.ais_data.dynamic_ships.stamp: data/external/nari_dynamic.csv
	psql --host=postgis --username=postgres --command "DROP TABLE IF EXISTS ais_data.dynamic_ships CASCADE;"
	psql --host=postgis --username=postgres --file=/workdir/src/init_ais_dynamic_ships.sql
	psql --host=postgis --username=postgres --file=/workdir/src/import_ais_dynamic_ships.sql
	psql --host=postgis --username=postgres \
	    --command "UPDATE ais_data.dynamic_ships SET mmsi = sourcemmsi, speed = speedoverground, geom3035 = ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 3035);"
	psql --host=postgis --username=postgres \
	    --command "SELECT COUNT(*) FROM ais_data.dynamic_ships;" \
	    | grep 19035630
	mkdir --parents $(@D)
	touch $@

data/processed/.data_analysis.segments.stamp: data/processed/.ais_data.dynamic_ships.stamp
	psql --host=postgis --username=postgres --file=/workdir/src/compute_vessel_segments.sql
	psql --host=postgis --username=postgres \
	    --command "SELECT COUNT(*) FROM data_analysis.segments;" \
	    | grep 19030575
	mkdir --parents $(@D)
	touch $@

data/processed/.data_analysis.stop_tables.stamp: data/processed/.data_analysis.segments.stamp
	psql --host=postgis --username=postgres --file=/workdir/src/compute_stop_tables.sql
	mkdir --parents $(@D)
	touch $@

data/processed/.data_analysis.stops.stamp: data/processed/.data_analysis.stop_tables.stamp
	psql --host=postgis --username=postgres --file=/workdir/src/compute_stops.sql
	psql --host=postgis --username=postgres \
	    --command "SELECT count(*) FROM data_analysis.stops WHERE duration_s >= (5*60) AND nb_pos > 5 AND avg_dist_centroid <= 10;" \
	    | grep 22987
	mkdir --parents $(@D)
	touch $@

data/processed/.data_analysis.cluster_stops.stamp: data/processed/.data_analysis.stops.stamp
	psql --host=postgis --username=postgres --file=/workdir/src/compute_cluster_stops.sql
	psql --host=postgis --username=postgres \
	    --command "SELECT count(DISTINCT cid) FROM data_analysis.cluster_stops WHERE cid IS NOT NULL;" \
	    | grep 353
	psql --host=postgis --username=postgres \
	    --command "SELECT count(*) FROM data_analysis.cluster_stops;" \
	    | grep 55304
	mkdir --parents $(@D)
	touch $@

data/processed/.data_analysis.clusters_stops_hulls.stamp: data/processed/.data_analysis.cluster_stops.stamp
	psql --host=postgis --username=postgres --file=/workdir/src/compute_cluster_hulls.sql
	mkdir --parents $(@D)
	touch $@

data/processed/.data_analysis.ports_voronoi.stamp: data/processed/.context_data.ports.stamp
	psql --host=postgis --username=postgres --file=/workdir/src/compute_voronoi.sql
	mkdir --parents $(@D)
	touch $@

# === OUTPUT FILE TARGETS ===

data/processed/brittany_maritime.gpkg: \
    data/processed/.data_analysis.ports_voronoi.stamp \
    data/processed/.context_data.europe_coastline_polygon.stamp
	mkdir --parents $(@D)
	bash /workdir/src/export_voronoi_gpkg.sh $@

reports/figures/voronoi_map.png: data/processed/brittany_maritime.gpkg
	mkdir --parents $(@D)
	bash /workdir/src/plot_voronoi_gmt.sh $< $@

data/processed/cluster_map.gpkg: \
    data/processed/.data_analysis.cluster_stops.stamp \
    data/processed/.context_data.europe_coastline_polygon.stamp
	mkdir --parents $(@D)
	bash /workdir/src/export_cluster_gpkg.sh $@

reports/figures/cluster_map.png: data/processed/cluster_map.gpkg
	mkdir --parents $(@D)
	bash /workdir/src/plot_cluster_gmt.sh $< $@

data/processed/brest_hulls.gpkg: \
    data/processed/.data_analysis.clusters_stops_hulls.stamp \
    data/processed/.context_data.europe_coastline_polygon.stamp
	mkdir --parents $(@D)
	bash /workdir/src/export_brest_hulls.sh $@

reports/figures/brest_hulls.png: data/processed/brest_hulls.gpkg
	mkdir --parents $(@D)
	bash /workdir/src/plot_brest_hulls.sh $< $@
