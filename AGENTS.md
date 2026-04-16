## Docker service

- `docker compose up islasgeci`: to start the PostGIS service

## psql commands

- Use long-form flags: `--host` not `-h`, `--username` not `-U`, `--dbname` not `-d`
- Run SQL file: `psql --host=postgis --username=postgres --file=/workdir/src/init_ais_data_static_ships.sql`
- Interactive: `psql --host=postgis --username=postgres`

## Coding Style

- Use `apt` instead of `apt-get`
- Prefer long-form flags: `--yes` not `-y`, `--force` not `-f`
- Multi-line formatting with backslash continuations for readability
- Explicit > concise
