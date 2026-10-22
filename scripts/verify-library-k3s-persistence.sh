#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
k=("$PWD/scripts/kubectl-lab.sh")
bash scripts/verify-library-k3s.sh
old_pod=$("${k[@]}" -n libratrack get pod postgres-0 -o jsonpath='{.metadata.uid}')
old_pvc=$("${k[@]}" -n libratrack get pvc data-postgres-0 -o jsonpath='{.metadata.uid}')
"${k[@]}" -n libratrack delete pod postgres-0 --wait=true --timeout=120s
"${k[@]}" -n libratrack wait --for=create pod/postgres-0 --timeout=120s
"${k[@]}" -n libratrack wait --for=condition=Ready pod/postgres-0 --timeout=180s
"${k[@]}" -n libratrack rollout restart deployment/libratrack
"${k[@]}" -n libratrack rollout status deployment/libratrack --timeout=180s
new_pod=$("${k[@]}" -n libratrack get pod postgres-0 -o jsonpath='{.metadata.uid}')
new_pvc=$("${k[@]}" -n libratrack get pvc data-postgres-0 -o jsonpath='{.metadata.uid}')
test "$old_pod" != "$new_pod"
test "$old_pvc" = "$new_pvc"
bash scripts/verify-library-k3s.sh
printf 'PASS PostgreSQL pod replaced, API restarted, PVC and saved book preserved.\n'
