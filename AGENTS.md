## Compose architecture

Three services in `docker-compose.yml`:

| Service | Role |
|---------|------|
| `islasgeci` | Main app container where `make` runs (R + postgresql-client + postgis) |
| `postgis` | PostGIS database; hostname `postgis`, user `postgres`, auth `trust` |
| `data` | One-shot init container that populates `data/external/` then exits |

`data/external/` is volume-mounted from the host. Files there are already in
the container at `/workdir/data/external/` — never `docker cp` into the container.

The user starts the container before invoking the agent. Run all commands inside
the container with:

`docker exec maritime_informatics_ci <command>`

For example:
- `docker exec maritime_informatics_ci make init-db`
- `docker exec maritime_informatics_ci make coastline`

## Make commands

| Command | Description |
|---------|-------------|
| `make setup` | Clean, install dependencies, build package |
| `make tests` | Run test suite |
| `make check` | Verify code formatting |
| `make coverage` | Generate coverage report |
| `make format` | Format code with styler |
| `make red` | Run failing tests (TDD) |
| `make green` | Run passing tests (TDD) |
| `make refactor` | Refactor with passing tests |
| `make init-db` | Initialize AIS data schema and import static ships |
| `make ships_view` | Create AIS ships view (depends on init-db) |
| `make coastline` | Import European coastline polygons |

### Make target conventions

- All targets must be listed in `.PHONY` (kept alphabetized)
- File targets use `$@` (output path) and `$(@D)` (parent directory)
- Create output directories with `mkdir --parents $(@D)`
- Targets compose via dependencies (e.g. `ships_view: init-db`)

## Database conventions

### Schemas

| Schema | Purpose |
|--------|---------|
| `ais_data` | AIS ship records (raw imports) |
| `context_data` | Geospatial context (ports, coastlines) |
| `data_analysis` | Derived/analytical outputs (e.g. Voronoi) |

### SQL scripts in `src/`

SQL is the single source of truth for DB schema and operations. Scripts in
`src/` are auditable, diff-able, and reviewable in PRs.

Two-phase pattern for data ingestion:
- `init_<entity>.sql` — creates schema + table
- `import_<entity>.sql` — uses `\copy` to load CSV data

## psql commands

- Use long-form flags: `--host` not `-h`, `--username` not `-U`, `--dbname` not `-d`
- Multi-statement SQL: `psql --host=postgis --username=postgres --file=/workdir/src/<script>.sql`
- Single statement: `psql --host=postgis --username=postgres --command '<SQL>'`
- CSV output: `psql --host=postgis --username=postgres --file=... --output=$@ --csv`
- Interactive: `psql --host=postgis --username=postgres`
- Reference SQL files by absolute path (`/workdir/src/...`), not relative
- Do **not** pipe shell output to `psql` stdin; always use `--file=` so the
  executed SQL is visible in a script

### Verification idiom

After a DB import, assert the row count by piping a count query through `grep`:

```sh
psql --host=postgis --username=postgres \
    --command "SELECT COUNT(*) FROM <schema>.<table>;" \
    | grep <expected_number>
```

Make fails if `grep` finds no match — implicit assertion.

## Shapefile imports

- `shp2pgsql` is provided by the `postgis` apt package (installed in `islasgeci`)
- Read SRID from the shapefile's `.prj` file before importing
  (e.g. ETRS_1989_LAEA → EPSG:3035)
- Generate SQL to `/tmp/<table>.sql`, then run `psql --file=/tmp/<table>.sql`
  (preserves the `--file=` pattern; avoids polluting `src/` with large
  generated dumps)
- Recommended flags: `-s <SRID> -I -D`
  - `-s` set SRID
  - `-I` create spatial index
  - `-D` dump format (faster)

## Data extraction

- Archives in `data/external/*.zip` are extracted in place:
  `unzip -o "data/external/[Cx] Foo.zip" -d data/external/`
- Generated outputs go to `data/processed/` (created by Make targets)

## Coding Style

- Use `apt` instead of `apt-get`
- Prefer long-form flags: `--yes` not `-y`, `--force` not `-f`
- Multi-line formatting with backslash continuations for readability
- Explicit > concise

## TDD workflow

The Makefile encodes a TDD cycle:

- `make red` — expects tests to fail; commits failing tests with `🛑🧪 Fail tests`
- `make green` — expects tests to pass; commits implementation with `✅ Pass tests`
- `make refactor` — expects tests to pass; commits both with `♻️  Refactor`

Each target runs `styler` first, then `devtools::test(stop_on_failure = TRUE)`,
and uses `git restore` to roll back on the wrong outcome.
