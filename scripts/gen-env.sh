#!/usr/bin/env bash
# Creates .env with strong random secrets. Won't overwrite an existing .env.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  echo ".env already exists — leaving it alone." >&2
  exit 0
fi

rand() { openssl rand -hex "$1"; }

cat > .env <<EOF
LITELLM_MASTER_KEY=sk-$(rand 24)
POSTGRES_PASSWORD=$(rand 24)
WEBUI_SECRET_KEY=$(rand 32)

ANTHROPIC_API_KEY=
OPENAI_API_KEY=
EOF
chmod 600 .env

echo "Created .env. Now add your ANTHROPIC_API_KEY:"
echo "  nano .env"
echo
echo "Your gateway master key (save it in your password manager):"
grep LITELLM_MASTER_KEY .env | cut -d= -f2
