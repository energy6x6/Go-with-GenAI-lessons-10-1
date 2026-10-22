#!/usr/bin/env python3
"""Create local secrets once without replacing an existing configuration."""
import os
from pathlib import Path
import secrets
from artifacts import artifacts_dir

root = Path(__file__).resolve().parent.parent
values = {
    "POSTGRES_DB": "libratrack_devops",
    "POSTGRES_USER": "libratrack_bootstrap",
    "POSTGRES_PASSWORD": secrets.token_urlsafe(36),
    "APP_DB_USER": "libratrack",
    "APP_DB_PASSWORD": secrets.token_urlsafe(36),
    "JWT_SECRET": secrets.token_urlsafe(48),
    "APP_PORT": "8080",
}
try:
    fd = os.open(root / ".env", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
except FileExistsError:
    print("Existing .env kept unchanged.")
else:
    with os.fdopen(fd, "w") as output:
        output.write("".join(f"{key}={value}\n" for key, value in values.items()))
    print("Created private .env (0600).")
accounts = artifacts_dir() / "accounts"
accounts.mkdir(parents=True, exist_ok=True, mode=0o700)
