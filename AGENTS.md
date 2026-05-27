## Compose architecture

Three services in `docker-compose.yml`:

| Service | Role |
|---------|------|
| `islasgeci` | Main app container where `make` runs (GMT + GDAL + postgresql-client + postgis) |
| `postgis` | PostGIS database; hostname `postgis`, user `postgres`, auth `trust` |
| `data` | One-shot init container that populates `data/external/` then exits |

`data/external/` is volume-mounted from the host. Files there are already in
the container at `/workdir/data/external/` — never `docker cp` into the container.

The `data/external/` directory is ephemeral. It is created and populated by the
`data` service on every compose run, and removed by `make clean`. Do not commit
files under `data/processed/` or `data/external/`.

Before invoking the agent, start the container:
- `docker compose run --name maritime_informatics_ci --rm islasgeci`

Then run commands inside the container:
- `docker exec maritime_informatics_ci <command>`

## Make commands

| Command | Description |
|---------|-------------|
| `make all` | Build the Voronoi map (default target) |
| `make clean` | Remove generated data and external archives |
| `make init` | Configure git inside the container |
| `make data/external/port.shp` | Extract port shapefile from zip |
| `make data/external/nari_dynamic.csv` | Extract AIS CSV from zip |
| `make data/processed/.context_data.ports.stamp` | Import port shapefile into `context_data.ports` |
| `make data/processed/.context_data.europe_coastline_polygon.stamp` | Import European coastline into `context_data.europe_coastline_polygon` |
| `make data/processed/.ais_data.dynamic_ships.stamp` | Import AIS dynamic positions into `ais_data.dynamic_ships` |
| `make data/processed/.data_analysis.segments.stamp` | Build vessel segments table from AIS positions |
| `make data/processed/.data_analysis.stop_tables.stamp` | Build stop-detection auxiliary tables from vessel segments |
| `make data/processed/.data_analysis.stops.stamp` | Build consolidated stops table from stop_begin and stop_end |
| `make data/processed/.data_analysis.ports_voronoi.stamp` | Compute Voronoi polygons from port locations |
| `make data/processed/brittany_maritime.gpkg` | Export all layers to GeoPackage |
| `make reports/figures/voronoi_map.png` | Generate Voronoi tessellation map |

### Make target conventions

- All phony targets must be listed in `.PHONY` (kept alphabetized)
- File targets use `$@` (output path) and `$(@D)` (parent directory)
- Extraction file targets have **no Make prerequisites** — the recipe runs only
  when the target file does not exist. Always `touch $@` after extraction:
  `unzip` preserves the archive's timestamps, and without `touch` the file
  appears older than expected on every subsequent invocation.
- Database tables use stamp files (`data/processed/.<schema>.<table>.stamp`)
  as proxies since Make cannot track database state natively
- Each stamp recipe creates its own schema with `CREATE SCHEMA IF NOT EXISTS`
  and is self-contained
- Each stamp recipe asserts row count with `psql ... | grep <expected_number>`
  for verification
- Separate extraction, import, compute, export, and plotting into distinct
  targets. Each target does ONE thing.
- Targets compose via dependencies (e.g.
  `voronoi_map.png: data/processed/brittany_maritime.gpkg`)

### Space- and special-character pitfalls

Filenames with spaces or parentheses break Make's automatic variables
(`$@`, `$<`, `$(@D)`) because Make passes the escaped form to the shell.
When a filename contains such characters:
- Hardcode the path in the recipe instead of using `$<` or `$@`
- For extraction that produces a file with special characters, bundle the
  extraction inline in the stamp recipe rather than creating a separate
  file target (e.g. the coastline shapefile).

## Database conventions

### Schemas

| Schema | Purpose |
|--------|---------|
| `context_data` | Geospatial context (ports, coastlines) |
| `ais_data` | AIS ship records (raw imports) |
| `data_analysis` | Derived/analytical outputs (e.g. Voronoi, segments) |

### SQL scripts in `src/`

SQL is the single source of truth for DB schema and operations. Scripts in
`src/` are auditable, diff-able, and reviewable in PRs.

- **Idempotency**: Scripts should start with `DROP TABLE IF EXISTS
  <schema>.<table>;` to ensure they can be run multiple times safely without
  "already exists" errors.
- **Index ownership**: Indexes belong with the table they index. Create them
  in the init SQL file (`init_<entity>.sql`), not in analysis scripts.
  For example, `idx_dynamic_ships_mmsi_t` and `idx_dynamic_ships_t` live in
  `init_ais_dynamic_ships.sql`.

## Coordinate Systems

- **Storage (EPSG:3035)**: Geospatial data is stored in the ETRS89-LAEA
  projection in PostGIS to ensure the `ST_VoronoiPolygons` calculation is
  geometrically accurate.
- **Visualization (EPSG:4326)**: For mapping with GMT, data is reprojected
  to lat/lon (decimal degrees) during export to GeoPackage. This simplifies
  the use of standard Mercator projections (`-JQ`).

## psql commands

- Use long-form flags: `--host` not `-h`, `--username` not `-U`,
  `--dbname` not `-d`
- Multi-statement SQL: `psql --host=postgis --username=postgres
  --file=/workdir/src/<script>.sql`
- Single statement: `psql --host=postgis --username=postgres
  --command '<SQL>'`
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
- **Warning:** `port.shp` has a mislabeled `.prj` file claiming WGS_1984
  (EPSG:4326). Actual coordinates are already in EPSG:3035. Always use
  `-s 3035` for port imports.
- Generate SQL to `/tmp/<table>.sql`, then run `psql --file=/tmp/<table>.sql`
- Recommended flags: `-s <SRID> -I -D`

## CSV imports

- Use `\copy` (psql meta-command, not SQL `COPY`) for CSV data; it reads
  from the client filesystem
- **Critical:** `\copy` must be on a **single line** — unlike SQL, psql
  backslash commands cannot span lines
- Two-phase pattern for CSV:
  1. `init_<entity>.sql` — creates schema + table with columns matching CSV headers
  2. `import_<entity>.sql` — `\copy` from the CSV file into the matching columns
- Computed columns (geometry, aliases) are added to the init table and
  populated via `UPDATE` in the Makefile after import, not in SQL scripts
- Coordinate transform for AIS dynamic data (lon/lat → EPSG:3035):
  ```sql
  ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 3035)
  ```

## Git conventions

- Commit messages use emoji prefixes followed by an imperative verb
  (e.g., `🔧 Fix column name typo`, `📝 Update AGENTS.md`)
- Emoji categories: 🗺️ Geospatial, 🛠️ Tooling, 🚢 Ships/Domain, 📥 Data import,
  📝 Documentation, 🔧 Maintenance, 🔓 Security, 🗄️ Database, 🤖 AI/Automation
- No Conventional Commits scopes (`feat:`, `fix:`) — the emoji serves that role
- Single-line subject, ~20 words max, no trailing period

## Documentation Strategy

| Filename | Audience | Contents | Domain | Cadence |
| :--- | :--- | :--- | :--- | :--- |
| **README.md** | User | User Manual: high-level overview and usage | Interface | Low |
| **AGENTS.md** | Developers | Developer Manual: architecture and conventions | Architecture | Medium |
| **DOCS.md** | Developers | Technical Specs: interfaces and data models | Implementation | High |
| **TODO.md** | Developers | Backlog: pending tasks and roadmap | Roadmap | Very High |
