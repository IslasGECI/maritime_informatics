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

Before invoking the agent, the user starts the container with:

- `docker compose run --name maritime_informatics_ci --rm islasgeci`

Then, the agent can run commands inside the container with:
- `docker exec maritime_informatics_ci <command>`

For example:
- `docker exec maritime_informatics_ci make data/processed/.context_data.ports.stamp`
- `docker exec maritime_informatics_ci make reports/figures/voronoi_map.png`

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
| `make data/processed/.data_analysis.ports_voronoi.stamp` | Compute Voronoi polygons from port locations |
| `make data/processed/brittany_maritime.gpkg` | Export all layers to GeoPackage |
| `make reports/figures/voronoi_map.png` | Generate Voronoi tessellation map |

### Make target conventions

- All phony targets must be listed in `.PHONY` (kept alphabetized)
- File targets use `$@` (output path) and `$(@D)` (parent directory)
- Database tables use stamp files (`data/processed/.<schema>.<table>.stamp`) as proxies since Make cannot track database state natively
- Each stamp recipe creates its own schema with `CREATE SCHEMA IF NOT EXISTS` and is self-contained
- Each stamp recipe asserts row count with `psql ... | grep <expected_number>` for verification
- Create output directories with `mkdir --parents $(@D)`
- Separate extraction, import, compute, export, and plotting into distinct targets
- Each target does ONE thing
- Targets compose via dependencies (e.g. `voronoi_map.png: data/processed/brittany_maritime.gpkg`)

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

- **Idempotency**: Scripts should start with `DROP TABLE IF EXISTS <schema>.<table>;`
  to ensure they can be run multiple times safely without "already exists" errors.

## Coordinate Systems

- **Storage (EPSG:3035)**: Geospatial data is stored in the ETRS89-LAEA projection
  in PostGIS to ensure the `ST_VoronoiPolygons` calculation is geometrically accurate.
- **Visualization (EPSG:4326)**: For mapping with GMT, data is reprojected to
  lat/lon (decimal degrees) during the export to GeoPackage. This simplifies
  the use of standard Mercator projections (`-JQ`).

## CI/CD "Render" Pipeline

The GitHub Actions workflow follows a **Build -> Render -> Push** lifecycle:

1. **Build**: The Docker image is built and stored as a temporary artifact.
2. **Render**: The pipeline is verified by running `make all` using a PostGIS
   service container.
   - **Data Extraction**: Unlike local development which uses volume mounts,
     CI uses the `docker cp` pattern to extract data from the
     `maritime_informatics_data` image into the runner's workspace.
   - **Verification**: If `make all` fails to generate the map artifact, the
     workflow stops and the image is NOT pushed to Docker Hub.
3. **Push**: Verified images are pushed to Docker Hub with `latest` and
   SHA-based tags.
4. **Cleanup**: Temporary artifacts (like the exported image) are deleted.

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
- **Warning:** `port.shp` has a mislabeled `.prj` file claiming WGS_1984
  (EPSG:4326). Actual coordinates are already in EPSG:3035. Always use
  `-s 3035` for port imports.
- Generate SQL to `/tmp/<table>.sql`, then run `psql --file=/tmp/<table>.sql`
  (preserves the `--file=` pattern; avoids polluting `src/` with large
  generated dumps)
- Recommended flags: `-s <SRID> -I -D`
  - `-s` set SRID
  - `-I` create spatial index
  - `-D` dump format (faster)

## CSV imports

- Use `\copy` (psql meta-command, not SQL `COPY`) for CSV data; it reads from the client filesystem
- **Critical:** `\copy` must be on a **single line** — unlike SQL, psql backslash commands cannot span lines
- Two-phase pattern for CSV data:
  1. `init_<entity>.sql` — creates schema + table with columns matching the CSV headers
  2. `import_<entity>.sql` — `\copy` from the CSV file into the matching columns
- Computed columns (geometry, aliases) are added to the init table and populated via `UPDATE` in the Makefile after import, not in SQL scripts
- Coordinate transform for AIS dynamic data (lon/lat → EPSG:3035):
  ```sql
  ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 3035)
  ```

## Plotting with GMT

- GMT 6 is used to render maps from GeoPackage data
- Layers are extracted to temporary shapefiles via `ogr2ogr` for GMT consumption
- Use predefined GMT colormaps (e.g. `/usr/share/gmt/cpt/paired.cpt`)
- All layers in the GeoPackage use EPSG:4326 (lat/lon) for consistency
- Layer order matters: bottom layer plotted first, top layer last

## Data extraction

- Archives in `data/external/*.zip` are extracted in place:
  `unzip -o "data/external/[Cx] Foo.zip" -d data/external/`
- Generated outputs go to `data/processed/` (created by Make targets)

## Coding Style

- Use `apt` instead of `apt-get`
- Prefer long-form flags: `--yes` not `-y`, `--force` not `-f`
- Multi-line formatting with backslash continuations for readability
- Explicit > concise

## Shell Script Conventions

- Use `${var:?error}` for mandatory arguments (no defaults)
- Let the Makefile handle default paths and file management
- Scripts should fail fast if arguments are missing

## GeoPackage Export Conventions

- Use temporary files for multi-step ogr2ogr operations
- Reprojection and clipping require two steps:
  1. Reproject to temp file with `-t_srs`
  2. Clip and append with `-clipsrc`
- Clean up temporary files after use

## Git conventions

- Commit messages use emoji prefixes followed by an imperative verb
  (e.g., `🔧 Fix column name typo`, `📝 Update AGENTS.md`)
- Emoji categories established in the project:

| Emoji | Category |
|-------|----------|
| 🗺️ | Geospatial data |
| 🛠️ | Tooling / configuration |
| 🚢 | Ships / domain feature |
| 📥 | Data import |
| 📝 | Documentation |
| 🔧 | Maintenance / fixes |
| 🔓 | Security |
| 🗄️ | Database |
| 🤖 | AI / automation |

- No Conventional Commits scopes (`feat:`, `fix:`) — the emoji serves that role
- Single-line subject, ~20 words max, no trailing period

## Documentation Strategy

| Filename | Audience | Contents | Domain | Cadence |
| :--- | :--- | :--- | :--- | :--- |
| **README.md** | User | **User Manual**: High-level overview of what the project is, its capabilities, and step-by-step instructions for use. | Interface | Low |
| **AGENTS.md** | Developers | **Developer Manual**: Detailed architectural design, core engineering principles, and operational guidelines. | Architecture | Medium |
| **DOCS.md** | Developers | **Technical Specs**: Exhaustive description of the current implementation and the internal mechanics of how it works. | Implementation | High |
| **TODO.md** | Developers | **Backlog**: A structured list of pending tasks, bugs, and roadmap items in a checklist format. | Roadmap | Very High |
