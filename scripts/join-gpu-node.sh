#!/usr/bin/env bash
# Run on ANY NVIDIA GPU machine you want to add — a rented Vast/RunPod box today,
# your home GPU tower later. Makes it a model backend reachable only over Tailscale.
#
#   sudo TS_HOSTNAME=gpu-home bash join-gpu-node.sh qwen3:8b
#
# Assumes the NVIDIA driver is already installed (`nvidia-smi` works).
set -euo pipefail

MODEL="${1:-qwen3:8b}"
HOSTNAME_TS="${TS_HOSTNAME:-gpu-node}"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi

if ! command -v nvidia-smi >/dev/null; then
  echo "nvidia-smi not found — install the NVIDIA driver first." >&2
  exit 1
fi

echo "==> Installing Tailscale and joining tailnet as '$HOSTNAME_TS'"
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled 2>/dev/null || true
tailscale up --ssh --hostname="$HOSTNAME_TS"
TS_IP=$(tailscale ip -4 | head -n1)

echo "==> Installing Ollama"
command -v ollama >/dev/null || curl -fsSL https://ollama.com/install.sh | sh

echo "==> Binding Ollama to the Tailscale interface only ($TS_IP)"
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf <<EOF
[Unit]
After=tailscaled.service
Wants=tailscaled.service

[Service]
Environment="OLLAMA_HOST=${TS_IP}:11434"
EOF
systemctl daemon-reload
systemctl restart ollama
sleep 3

echo "==> Pulling model: $MODEL"
OLLAMA_HOST="${TS_IP}:11434" ollama pull "$MODEL"

echo
echo "Node ready. Add this to litellm/config.yaml on the anchor:"
echo
echo "  - model_name: local-chat"
echo "    litellm_params:"
echo "      model: ollama_chat/${MODEL}"
echo "      api_base: http://${TS_IP}:11434"
echo
echo "Then on the anchor: docker compose restart litellm"
