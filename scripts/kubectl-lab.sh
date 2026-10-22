#!/usr/bin/env bash
set -euo pipefail
exec kubectl --kubeconfig "${HOME}/.kube/projectgo-k3s.yaml" "$@"
