all: reports/figures/voronoi_map.png

.PHONY: all clean init

clean:
	rm --force --recursive data/processed
	rm --force --recursive data/external

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
