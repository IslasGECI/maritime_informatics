all: check coverage

.PHONY: \
    check \
    clean \
    coverage \
    format \
    green \
    init \
    init-db \
    install \
    mutants \
    red \
    refactor \
    setup \
    ships_view \
    tests

check:
	R -e "library(styler)" \
      -e "resumen <- style_dir('R')" \
      -e "resumen <- rbind(resumen, style_dir('tests'))" \
      -e "resumen <- rbind(resumen, style_dir('tests/testthat'))" \
      -e "any(resumen[[2]])" \
      | grep FALSE

clean:
	rm --force *.tar.gz
	rm --force --recursive data/processed
	rm --force --recursive tests/testthat/_snaps
	rm --force NAMESPACE

coverage: setup tests
	Rscript tests/testthat/coverage.R

format:
	R -e "library(styler)" \
      -e "style_dir('R')" \
      -e "style_dir('tests')" \
      -e "style_dir('tests/testthat')"

init: setup tests
	git config --global --add safe.directory /workdir
	git config --global user.name "Ciencia de Datos • GECI"
	git config --global user.email "ciencia.datos@islas.org.mx"

mutants:
	@echo "En espera del doctorado de Evaristo 👾🎉🎓"


setup: clean install

red: format
	Rscript -e "devtools::test(stop_on_failure = TRUE)" \
	&& git restore . \
	|| (git add tests/testthat/*.R && git commit -m "🛑🧪 Fail tests")
	chmod g+w -R .

green: format
	Rscript -e "devtools::test(stop_on_failure = TRUE)" \
	&& (git add R/*.R && git commit -m "✅ Pass tests") \
	|| git restore .
	chmod g+w -R .

refactor: format
	Rscript -e "devtools::test(stop_on_failure = TRUE)" \
	&& (git add R/*.R tests/testthat/*.R && git commit -m "♻️  Refactor") \
	|| git restore .
	chmod g+w -R .

install:
	R -e "devtools::install()" && \
	R -e "devtools::check(error_on = 'error')" && \
	R -e "devtools::build()"

tests:
	Rscript -e "devtools::test(stop_on_failure = TRUE)"

init-db:
	psql --host=postgis --username=postgres --command 'DROP SCHEMA IF EXISTS ais_data CASCADE;'
	psql --host=postgis --username=postgres --file=/workdir/src/init_ais_data_static_ships.sql
	unzip -o "data/external/[P1] AIS Data.zip" "nari_static.csv" -d data/external/
	psql --host=postgis --username=postgres --file=/workdir/src/import_ais_static_ships.sql
	psql --host=postgis --username=postgres --command "SELECT COUNT(DISTINCT shipname) FROM ais_data.static_ships;" \
		| grep 4824

ships_view: init-db
	psql --host=postgis --username=postgres --file=/workdir/src/create_ais_ships_view.sql

data/processed/n_empty_shipname.csv: ships_view
	mkdir --parents $(@D)
	psql --host=postgis --username=postgres --file=/workdir/src/count_empty_shipname.sql --output=$@ --csv

data/processed/n_reused_mmsi.csv: ships_view
	mkdir --parents $(@D)
	psql --host=postgis --username=postgres --file=/workdir/src/compute_reused_mmsi_count.sql --output=$@ --csv
