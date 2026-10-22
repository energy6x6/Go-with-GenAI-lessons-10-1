#!/usr/bin/env python3
"""Exercise the real HTTP service; keep passwords and JWTs out of output."""
import argparse
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request
import uuid
from artifacts import artifacts_dir

parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["create", "check"])
parser.add_argument("--url", default="http://127.0.0.1:8080")
parser.add_argument("--state", type=Path, default=artifacts_dir() / "library-proof.json")
parser.add_argument("--title", default="Docker Compose — перевірка збереження")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
proof = args.state
proof.parent.mkdir(parents=True, exist_ok=True, mode=0o700)


def request(path, *, data=None, token=None, status=200):
    headers = {}
    if data is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(
        args.url.rstrip("/") + path,
        data=None if data is None else json.dumps(data).encode(), headers=headers,
    )
    try:
        response = urllib.request.urlopen(req, timeout=10)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        if response.status != status:
            raise SystemExit(f"FAIL {path}: HTTP {response.status}, expected {status}")
        return response.read()


assert json.loads(request("/health"))["status"] == "ok"
assert b"LibraTrack" in request("/catalog")
assert b"swagger" in request("/swagger/index.html").lower()
books = json.loads(request("/api/v1/books?limit=100"))
assert len(books) >= 10, "Seed books are missing"
print(f"PASS health, embedded catalog, Swagger, database read ({len(books)} books)")

if args.mode == "create" and not proof.exists():
    categories = json.loads(request("/api/v1/categories"))
    authors = json.loads(request("/api/v1/authors"))
    book = {
        "title": args.title,
        "isbn": "DEVOPS-" + uuid.uuid4().hex[:12],
        "category_id": categories[0]["id"],
        "author_ids": [authors[0]["id"]],
        "description": "Книгу додано через API LibraTrack для перевірки збереження даних.",
        "published_year": 2026,
    }
    request("/api/v1/books", data=book, status=401)
    credentials = (artifacts_dir() / "accounts/.demo-accounts.txt").read_text()
    match = re.search(r"Role: admin\s+Email: (\S+)\s+Password: (\S+)", credentials)
    if not match:
        raise SystemExit("Cannot find the local admin account")
    login = json.loads(request("/api/v1/auth/login", data={
        "email": match[1], "password": match[2],
    }))
    created = json.loads(request("/api/v1/books", data=book, token=login["token"], status=201))
    state = {"id": created["id"], "title": book["title"], "isbn": book["isbn"]}
    with os.fdopen(os.open(proof, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as output:
        json.dump(state, output, ensure_ascii=False, indent=2)
        output.write("\n")
    print("PASS anonymous write rejected; admin login and database write succeeded")

if not proof.exists():
    raise SystemExit("Run create first to establish the persistence proof")
state = json.loads(proof.read_text())
stored = json.loads(request(f'/api/v1/books/{state["id"]}'))
assert all(stored[key] == value for key, value in state.items()), "Stored book changed"
assert state["title"].encode() in request("/catalog?q=" + urllib.parse.quote(state["isbn"]))
print(f'PASS saved book id={state["id"]}, ISBN={state["isbn"]}: API and catalog agree')
