#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
"$project_root/scripts/kubectl-lab.sh" get nodes -o json | python3 -c '
import ipaddress, json, sys
for node in json.load(sys.stdin)["items"]:
    for item in node["status"]["addresses"]:
        if item["type"] == "InternalIP" and ipaddress.ip_address(item["address"]).version == 4:
            print(item["address"])
            sys.exit(0)
raise SystemExit("No node IPv4 address found")
'
