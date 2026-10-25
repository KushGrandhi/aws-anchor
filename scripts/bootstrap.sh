#!/usr/bin/env bash
# Run once on a fresh Lightsail Ubuntu 24.04 instance:
#   sudo bash scripts/bootstrap.sh
# Installs: swap, Docker, Tailscale. Safe to re-run.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash scripts/bootstrap.sh" >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-ubuntu}"
HOSTNAME_TS="${TS_HOSTNAME:-anchor}"

echo "==> Updating packages"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
apt-get install -y curl git ca-certificates

echo "==> Adding 4GB swap (small instances need headroom for the containers)"
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  sysctl -w vm.swappiness=10
  echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf
fi

echo "==> Installing Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker "$TARGET_USER"
systemctl enable --now docker

echo "==> Fetching your gateway (llm_routing_server) into ./gateway-src"
ANCHOR_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GATEWAY_REPO="${GATEWAY_REPO:-https://github.com/KushGrandhi/llm_routing_server.git}"
if [[ ! -d "$ANCHOR_DIR/gateway-src/.git" ]]; then
  sudo -u "$TARGET_USER" git clone "$GATEWAY_REPO" "$ANCHOR_DIR/gateway-src"
fi
if ! grep -qi '^tenacity' "$ANCHOR_DIR/gateway-src/requirements.txt"; then
  echo "!!  gateway-src/requirements.txt is missing 'tenacity' — chat calls with retries will fail."
  echo "!!  Commit gateway/0001-add-tenacity.patch to your llm_routing_server repo, then:"
  echo "!!    cd gateway-src && git pull"
fi

echo "==> Installing Tailscale"
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable --now tailscaled

echo "==> Joining your tailnet as '$HOSTNAME_TS'"
echo "    Open the login URL printed below in your browser to approve this machine."
tailscale up --ssh --hostname="$HOSTNAME_TS"

echo
echo "Done. Next:"
echo "  1. Log out and back in (so docker works without sudo)"
echo "  2. bash scripts/gen-env.sh   and add your ANTHROPIC_API_KEY to .env"
echo "  3. docker compose up -d --build"
echo "  4. bash scripts/expose.sh"
