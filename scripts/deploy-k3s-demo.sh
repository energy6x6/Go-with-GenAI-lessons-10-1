#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_root/scripts/artifacts.sh"
export KUBECONFIG="${HOME}/.kube/projectgo-k3s.yaml"
mkdir -p "$PROJECTGO_ARTIFACTS_DIR/k3s"

docker build -t projectgo/k3s-demo:1.0.0 "$project_root/demos/http"
docker save -o "$PROJECTGO_ARTIFACTS_DIR/k3s/demo-api.tar" projectgo/k3s-demo:1.0.0
# Docker and K3s containerd have separate image stores.
sudo k3s ctr images import "$PROJECTGO_ARTIFACTS_DIR/k3s/demo-api.tar"
kubectl apply -f "$project_root/k8s/demo-api.yaml"
kubectl -n projectgo-demo rollout status deployment/demo-api --timeout=180s
exec bash "$project_root/scripts/verify-k3s.sh"
