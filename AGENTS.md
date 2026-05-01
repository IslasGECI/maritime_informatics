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

The user starts the container before invoking the agent. Run all commands inside
the container with:

`docker exec maritime_informatics_ci <command>`

For example:
- `docker exec maritime_informatics_ci make init_db`
- `docker exec maritime_informatics_ci make reports/figures/voronoi_map.png`

## Make commands

| Command | Description |
|---------|-------------|
| `make all` | Build the Voronoi map (default target) |
| `make clean` | Remove generated data and external archives |
| `make init` | Configure git inside the container |
| `make init_db` | Initialize context data schema and import ports + coastline |
| `make reports/figures/voronoi_map.png` | Generate Voronoi tessellation map |

### Make target conventions

- All phony targets must be listed in `.PHONY` (kept alphabetized)
- File targets use `$@` (output path) and `$(@D)` (parent directory)
- Create output directories with `mkdir --parents $(@D)`
- Separate compute, export, and plotting into distinct targets
- Use intermediate file targets (e.g. `data/processed/%.gpkg`) for dependency tracking
- Each target does ONE thing: compute, export, or plot
- Targets compose via dependencies (e.g. `voronoi_map.png: init_db`)

## Database conventions

### Schemas

| Schema | Purpose |
|--------|---------|
| `context_data` | Geospatial context (ports, coastlines) |
| `data_analysis` | Derived/analytical outputs (e.g. Voronoi) |

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
