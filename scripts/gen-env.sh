#!/usr/bin/env bash
# Creates .env with strong random secrets. Won't overwrite an existing .env.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  echo ".env already exists — leaving it alone." >&2
  exit 0
fi

rand() { openssl rand -hex "$1"; }
PERSONAL_KEY="gw-$(rand 24)"   # for you: scripts, Jarvis, editors
WEBUI_KEY="gw-$(rand 24)"      # used only by Open WebUI (separate key = separate usage stats)

cat > .env <<EOF
# Keys clients use to call the gateway (comma-separated)
GATEWAY_API_KEYS=${PERSONAL_KEY},${WEBUI_KEY}
WEBUI_GATEWAY_KEY=${WEBUI_KEY}
WEBUI_SECRET_KEY=$(rand 32)

# Provider keys — fill these in
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
GEMINI_API_KEY=
GROQ_API_KEY=
EOF
chmod 600 .env

echo "Created .env. Now add your ANTHROPIC_API_KEY:"
echo "  nano .env"
echo
echo "Your personal gateway key (save it in your password manager):"
echo "  ${PERSONAL_KEY}"
