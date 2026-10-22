#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/artifacts.sh
result=0
docker compose --profile test run --rm -T tests >"$PROJECTGO_ARTIFACTS_DIR/library-tests.jsonl" || result=$?
python3 - "$result" "$PROJECTGO_ARTIFACTS_DIR/library-tests.jsonl" <<'PY'
from collections import Counter
import json
from pathlib import Path
import sys

counts = Counter()
packages = Counter()
for line in Path(sys.argv[2]).read_text().splitlines():
    event = json.loads(line)
    action = event.get("Action")
    if event.get("Test") and action in ("pass", "fail", "skip"):
        counts[action] += 1
    elif not event.get("Test") and action in ("pass", "fail"):
        packages[action] += 1
print(f'Tests with PostgreSQL and race detector: PASS={counts["pass"]}, FAIL={counts["fail"]}, SKIP={counts["skip"]}')
print(f'Packages: PASS={packages["pass"]}, FAIL={packages["fail"]}')
if int(sys.argv[1]) or not counts["pass"] or counts["fail"] or counts["skip"] or packages["fail"]:
    raise SystemExit(f"FAIL: inspect {sys.argv[2]}")
PY
docker compose --profile test run --rm -T tests go vet -p 2 ./...
printf 'PASS go vet ./...\n'
