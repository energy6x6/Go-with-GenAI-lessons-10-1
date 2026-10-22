#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/artifacts.sh
k=("$project_root/scripts/kubectl-lab.sh")
"${k[@]}" -n libratrack rollout status statefulset/postgres --timeout=180s
"${k[@]}" -n libratrack rollout status deployment/libratrack --timeout=180s
node_ip=$(bash scripts/library-node-ip.sh)
state="$PROJECTGO_ARTIFACTS_DIR/k8s/library-proof.json"
mode=check
[[ -f "$state" ]] || mode=create
python3 scripts/verify-library.py "$mode" --url "http://$node_ip:30081" \
  --state "$state" --title 'Kubernetes — перевірка збереження'
"${k[@]}" -n libratrack get deploy,statefulset,pods,svc,pvc -o wide
