#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_root/scripts/artifacts.sh"
mkdir -p "$PROJECTGO_ARTIFACTS_DIR/lambda"

docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e CGO_ENABLED=0 -e GOOS=linux -e GOARCH=amd64 \
  -e GOCACHE=/tmp/go-cache -e GOMODCACHE=/tmp/go-mod \
  -v "$project_root:/src:ro" -v "$PROJECTGO_ARTIFACTS_DIR/lambda:/output" -w /src/demos/lambda \
  golang:1.27.3@sha256:f20d83a83e18dbd2a4714b8ffd4b30b287b6243962dd75608e86abcc63ba4efc \
  go build -trimpath -tags lambda.norpc -o /output/bootstrap .

(cd "$PROJECTGO_ARTIFACTS_DIR/lambda" && zip -q function.zip bootstrap)
unzip -l "$PROJECTGO_ARTIFACTS_DIR/lambda/function.zip"
