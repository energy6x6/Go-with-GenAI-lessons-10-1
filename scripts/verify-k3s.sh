#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${HOME}/.kube/projectgo-k3s.yaml"

kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl -n projectgo-demo rollout status deployment/demo-api --timeout=120s
kubectl get nodes -o wide
kubectl -n projectgo-demo get deployments,pods,services -o wide
node_ip="$(kubectl get nodes -o json | python3 -c '
import ipaddress, json, sys
addresses = json.load(sys.stdin)["items"][0]["status"]["addresses"]
print(next(a["address"] for a in addresses
           if a["type"] == "InternalIP" and ipaddress.ip_address(a["address"]).version == 4))
')"
test "$(curl --fail --silent --show-error --retry 10 --retry-connrefused --retry-delay 1 --max-time 15 "http://$node_ip:30080/health")" = ok
printf 'HTTP /health: PASS (%s:30080)\n' "$node_ip"
test "$(curl --fail --silent --show-error --max-time 15 "http://$node_ip:30080/ask")" = 'LLM key set: false'
printf 'HTTP /ask: PASS\n'
