#!/usr/bin/env bash
set -euo pipefail

# Run on the Ubuntu guest: sudo bash install-docker.sh <login-user>
# Source: https://docs.docker.com/engine/install/ubuntu/
if [[ "$EUID" -ne 0 ]]; then
  echo "Run this script with sudo inside the Ubuntu VM." >&2
  exit 1
fi

login_user="${1:-${SUDO_USER:-}}"
if [[ -z "$login_user" || "$login_user" == root ]]; then
  echo "Specify the non-root login user as the first argument." >&2
  exit 1
fi
id "$login_user" >/dev/null

. /etc/os-release
if [[ "$ID" != ubuntu || "$VERSION_ID" != 24.04 ]]; then
  echo "This lab provisioning script requires Ubuntu 24.04." >&2
  exit 1
fi

for package in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc; do
  if [[ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)" == 'install ok installed' ]]; then
    echo "Conflicting package installed: $package. Review it before proceeding." >&2
    exit 1
  fi
done

export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=3 update
apt-get -o DPkg::Lock::Timeout=120 install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl --fail --silent --show-error --location --retry 3 \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod 0644 /etc/apt/keyrings/docker.asc

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get -o Acquire::Retries=3 update
apt-get -o DPkg::Lock::Timeout=120 install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker.service containerd.service
usermod -aG docker "$login_user"

docker --version
docker compose version
docker buildx version
echo "Docker installed. Reconnect your SSH session to use Docker without sudo."
