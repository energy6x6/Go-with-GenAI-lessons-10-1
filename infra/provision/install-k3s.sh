#!/usr/bin/env bash
set -euo pipefail

# Run inside Ubuntu: sudo bash infra/provision/install-k3s.sh osboxes
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
login_home="$(getent passwd "$login_user" | cut -d: -f6)"
login_group="$(id -gn "$login_user")"

installer="$(mktemp)"
configuration="$(mktemp)"
trap 'rm -f "$installer" "$configuration"' EXIT
cat > "$configuration" <<'YAML'
# ProjectGo single-node lab. K3s uses its own containerd runtime.
write-kubeconfig-mode: "0600"
# Keep the VM's existing swap available to host processes; pods use NoSwap.
kubelet-arg:
  - "fail-swap-on=false"
YAML
install -d -m 0755 /etc/rancher/k3s
if [[ -f /etc/rancher/k3s/config.yaml ]] && ! cmp -s "$configuration" /etc/rancher/k3s/config.yaml; then
  echo "Existing K3s configuration differs; review it before provisioning." >&2
  exit 1
fi
install -m 0644 "$configuration" /etc/rancher/k3s/config.yaml

curl --fail --silent --show-error --location --retry 3 \
  'https://raw.githubusercontent.com/k3s-io/k3s/v1.36.5%2Bk3s1/install.sh' \
  -o "$installer"
printf '%s  %s\n' \
  46177d4c99440b4c0311b67233823a8e8a2fc09693f6c89af1a7161e152fbfad \
  "$installer" | sha256sum --check -
INSTALL_K3S_VERSION='v1.36.5+k3s1' sh "$installer" server

k3s kubectl wait --for=create "node/$(hostname)" --timeout=120s
k3s kubectl wait --for=condition=Ready "node/$(hostname)" --timeout=180s
install -d -m 0700 -o "$login_user" -g "$login_group" "$login_home/.kube"
install -m 0600 -o "$login_user" -g "$login_group" \
  /etc/rancher/k3s/k3s.yaml "$login_home/.kube/projectgo-k3s.yaml"
k3s --version
k3s kubectl get nodes -o wide
echo "User kubeconfig: $login_home/.kube/projectgo-k3s.yaml"
