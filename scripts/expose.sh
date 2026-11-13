#!/usr/bin/env bash
# Publishes the chat UI and gateway to your tailnet ONLY (not the internet),
# with automatic HTTPS certificates.
#
# Requires: in the Tailscale admin console → DNS, enable MagicDNS and HTTPS Certificates.
set -euo pipefail

sudo tailscale serve --bg --https=443  http://127.0.0.1:3000   # Open WebUI
sudo tailscale serve --bg --https=8443 http://127.0.0.1:5000   # llm_routing_server gateway

# Aurora is the one PUBLIC service (Funnel): anyone can open a share link; using it needs a workspace key.
# Needs Funnel allowed for this machine: Tailscale admin console → Access controls → "funnel" node attribute.
sudo tailscale funnel --bg --https=10000 http://127.0.0.1:4317   # Aurora (public)

NAME=$(tailscale status --json | grep -m1 '"DNSName"' | cut -d'"' -f4 | sed 's/\.$//')

# Point aurora at its public address (first run only), then restart it to pick that up.
cd "$(dirname "$0")/.."
if [[ -f .env ]] && grep -q '^AURORA_PUBLIC_URL=$' .env; then
  sed -i "s|^AURORA_PUBLIC_URL=$|AURORA_PUBLIC_URL=https://${NAME}:10000|" .env
  docker compose up -d aurora
fi
echo
echo "From any device on your tailnet:"
echo "  Chat UI : https://${NAME}"
echo "  Gateway : https://${NAME}:8443/v1   (Authorization: Bearer <your gateway key>)"
echo
echo "From anywhere (public):"
echo "  Aurora  : https://${NAME}:10000   — connect Claude Code with:"
echo "    curl -s -X POST https://${NAME}:10000/api/keys -H 'content-type: application/json' -d '{\"invite\":\"<AURORA_INVITE>\"}'"
echo "    claude mcp add --transport http aurora https://${NAME}:10000/mcp --header \"Authorization: Bearer <key>\""
