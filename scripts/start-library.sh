#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/artifacts.sh
python3 scripts/init-library-env.py
docker compose config --quiet
docker compose up -d --build --wait postgres api
docker compose --profile tools run --rm -T --user "$(id -u):$(id -g)" demo-users
printf 'Catalog: http://127.0.0.1:8080/catalog\nPrivate accounts: %s/accounts/.demo-accounts.txt\n' "$PROJECTGO_ARTIFACTS_DIR"
docker compose ps
