#!/usr/bin/env bash
set -euo pipefail
if [[ "$EUID" -eq 0 ]]; then
  echo "Run this script as the Ubuntu login user, not as root." >&2
  exit 1
fi
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
sudo apt-get -o DPkg::Lock::Timeout=120 install -y python3-venv zip
python3 -m venv "${HOME}/.venvs/devops-aws"
"${HOME}/.venvs/devops-aws/bin/pip" install -r "$script_dir/aws-tools-requirements.txt"
"${HOME}/.venvs/devops-aws/bin/aws" --version
