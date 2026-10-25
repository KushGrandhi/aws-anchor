#!/usr/bin/env bash
# Publishes the chat UI and gateway to your tailnet ONLY (not the internet),
# with automatic HTTPS certificates.
#
# Requires: in the Tailscale admin console → DNS, enable MagicDNS and HTTPS Certificates.
set -euo pipefail

sudo tailscale serve --bg --https=443  http://127.0.0.1:3000   # Open WebUI
sudo tailscale serve --bg --https=8443 http://127.0.0.1:4000   # LiteLLM gateway

NAME=$(tailscale status --json | grep -m1 '"DNSName"' | cut -d'"' -f4 | sed 's/\.$//')
echo
echo "From any device on your tailnet:"
echo "  Chat UI : https://${NAME}"
echo "  Gateway : https://${NAME}:8443/v1   (Authorization: Bearer <LITELLM_MASTER_KEY>)"
