## Docker Services

- `docker compose up -d postgis` - Start PostGIS database
- `docker compose run --rm islasgeci` - Interactive shell in container
- `docker compose run --rm postgis psql -h postgis -U postgres` - Connect to DB

PostGIS connection: host=`postgis`, port=`5432`, user=`postgres`, password=`4705`

## Coding Style

- Use `apt` instead of `apt-get`
- Prefer long-form flags: `--yes` not `-y`, `--force` not `-f`
- Multi-line formatting with backslash continuations for readability
- Explicit > concise
