#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/artifacts.sh
umask 077
mkdir -p "$PROJECTGO_ARTIFACTS_DIR/k8s"
k=("$project_root/scripts/kubectl-lab.sh")

docker image inspect projectgo/libratrack:lesson10-1 >/dev/null
docker save -o "$PROJECTGO_ARTIFACTS_DIR/k8s/libratrack-image.tar" projectgo/libratrack:lesson10-1
sudo k3s ctr images import "$PROJECTGO_ARTIFACTS_DIR/k8s/libratrack-image.tar"
"${k[@]}" apply -f k8s/library/namespace.yaml
python3 scripts/init-k3s-secrets.py
"${k[@]}" apply -f k8s/library/postgres.yaml
"${k[@]}" -n libratrack rollout status statefulset/postgres --timeout=240s

# Restore only into an empty target; existing Kubernetes data is authoritative.
existing=$("${k[@]}" -n libratrack exec postgres-0 -- psql -U libratrack -d libratrack_k3s -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")
if [[ "$existing" == 0 ]]; then
  docker compose exec -T postgres pg_dump -U libratrack_bootstrap -d libratrack_devops \
    --format=custom --no-owner --no-acl >"$PROJECTGO_ARTIFACTS_DIR/k8s/compose-snapshot.dump"
  "${k[@]}" -n libratrack exec -i postgres-0 -- pg_restore -U libratrack -d libratrack_k3s \
    --exit-on-error --no-owner --no-privileges <"$PROJECTGO_ARTIFACTS_DIR/k8s/compose-snapshot.dump"
  printf 'Restored a copy of Compose data into the new Kubernetes database.\n'
else
  printf 'Existing Kubernetes database kept unchanged.\n'
fi
"${k[@]}" apply -f k8s/library/api.yaml
"${k[@]}" -n libratrack rollout restart deployment/libratrack
"${k[@]}" -n libratrack rollout status deployment/libratrack --timeout=240s
exec bash scripts/verify-library-k3s.sh
