#!/usr/bin/env python3
"""Keep generated Kubernetes credentials outside the checkout."""
import base64
import json
import os
from pathlib import Path
import secrets
import subprocess
from artifacts import artifacts_dir

root = Path(__file__).resolve().parent.parent
kubectl = str(root / "scripts/kubectl-lab.sh")
target = artifacts_dir() / "k8s/secrets.json"
target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
if target.exists():
    values = json.loads(target.read_text())
else:
    existing = subprocess.run([kubectl, "-n", "libratrack", "get", "secret", "library-app", "--ignore-not-found", "-o", "name"], check=True, capture_output=True, text=True).stdout.strip()
    if existing:
        raise SystemExit("Existing Kubernetes credentials found. Restore the private secrets.json before redeploying.")
    values = {key: secrets.token_urlsafe(48) for key in ("POSTGRES_PASSWORD", "APP_DB_PASSWORD", "JWT_SECRET")}
    with os.fdopen(os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600), "w") as output:
        json.dump(values, output)
for name, keys in [("library-database", ["POSTGRES_PASSWORD"]), ("library-app", ["APP_DB_PASSWORD", "JWT_SECRET"])]:
    manifest = {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": name, "namespace": "libratrack"}, "type": "Opaque", "data": {key: base64.b64encode(values[key].encode()).decode() for key in keys}}
    subprocess.run([kubectl, "apply", "--server-side", "-f", "-"], input=json.dumps(manifest), text=True, check=True)
print("Kubernetes credentials loaded; private values kept outside the checkout.")
