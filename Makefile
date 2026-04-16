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
    red \
    refactor \
    setup \
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

setup: clean install

install:
	R -e "devtools::install()" && \
	R -e "devtools::check(error_on = 'error')" && \
	R -e "devtools::build()"

tests:
	Rscript -e "devtools::test(stop_on_failure = TRUE)"

init-db:
	psql -h postgis -U postgres -f /workdir/src/init_ais_data_static_ships.sql
