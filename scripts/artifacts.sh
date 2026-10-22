#!/usr/bin/env bash
# Store runtime files beside the checkout, never in the source tree.
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECTGO_ARTIFACTS_DIR="${PROJECTGO_ARTIFACTS_DIR:-$(dirname "$project_root")/projectgo-artifacts}"
mkdir -p "$PROJECTGO_ARTIFACTS_DIR"
chmod 700 "$PROJECTGO_ARTIFACTS_DIR"
