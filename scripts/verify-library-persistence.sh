#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/verify-library.py create
old_api=$(docker compose ps -q api)
old_db=$(docker compose ps -q postgres)
old_volume=$(docker inspect "$old_db" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}')
test -n "$old_volume"
docker compose up -d --force-recreate --wait postgres api
new_api=$(docker compose ps -q api)
new_db=$(docker compose ps -q postgres)
new_volume=$(docker inspect "$new_db" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}')
test "$old_api" != "$new_api"
test "$old_db" != "$new_db"
test "$old_volume" = "$new_volume"
python3 scripts/verify-library.py check
printf 'PASS both containers recreated; PostgreSQL volume preserved: %s\n' "$new_volume"
docker compose ps
