all: reports/figures/voronoi_map.png

.PHONY: \
    all \
    clean \
    init \
    init_db

clean:
	rm --force --recursive data/processed
	rm --force --recursive data/external

init:
	git config --global --add safe.directory /workdir
	git config --global user.name "Ciencia de Datos • GECI"
	git config --global user.email "ciencia.datos@islas.org.mx"

init_db:
	psql --host=postgis --username=postgres --command "DROP SCHEMA IF EXISTS context_data CASCADE; CREATE SCHEMA context_data;"
	unzip -o "data/external/[C1] Ports of Brittany.zip" -d data/external/
	shp2pgsql -s 3035 -I -D \
	    "data/external/port.shp" \
	    context_data.ports \
	    > /tmp/ports.sql
	psql --host=postgis --username=postgres --file=/tmp/ports.sql
	psql --host=postgis --username=postgres --command "ALTER TABLE context_data.ports RENAME COLUMN geom TO geom3035;"
	psql --host=postgis --username=postgres \
	    --command "SELECT COUNT(*) FROM context_data.ports;" \
	    | grep 222
	unzip -o "data/external/[C2] European Coastline.zip" -d data/external/
	shp2pgsql -s 3035 -I -D \
	    "data/external/Europe Coastline (Polygone).shp" \
	    context_data.europe_coastline_polygon \
	    > /tmp/europe_coastline_polygon.sql
	psql --host=postgis --username=postgres --file=/tmp/europe_coastline_polygon.sql
	psql --host=postgis --username=postgres \
	    --command "SELECT COUNT(*) FROM context_data.europe_coastline_polygon;" \
	    | grep 71514

reports/figures/voronoi_map.png: data/processed/brittany_maritime.gpkg
	mkdir --parents $(@D)
	bash /workdir/src/plot_voronoi_gmt.sh data/processed/brittany_maritime.gpkg $@

data/processed/brittany_maritime.gpkg: init_db
	mkdir --parents $(@D)
	psql --host=postgis --username=postgres --file=/workdir/src/compute_voronoi.sql
	bash /workdir/src/export_voronoi_gpkg.sh $@
