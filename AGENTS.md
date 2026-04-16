## Docker service

- `docker compose up islasgeci`: start the PostGIS service
- `make init-db`: initialize AIS data schema in PostGIS

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

## psql commands

- Use long-form flags: `--host` not `-h`, `--username` not `-U`, `--dbname` not `-d`
- Run SQL file: `psql --host=postgis --username=postgres --file=/workdir/src/init_ais_data_static_ships.sql`
- Interactive: `psql --host=postgis --username=postgres`

## Coding Style

- Use `apt` instead of `apt-get`
- Prefer long-form flags: `--yes` not `-y`, `--force` not `-f`
- Multi-line formatting with backslash continuations for readability
- Explicit > concise
