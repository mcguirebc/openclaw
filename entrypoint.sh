#!/usr/bin/env bash
set -euo pipefail

export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-/data/openclaw}"
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$OPENCLAW_STATE_DIR/openclaw.json}"
export OPENCLAW_CONFIG_TEMPLATE="${OPENCLAW_CONFIG_TEMPLATE:-/app/infra/openclaw/openclaw.json}"

mkdir -p "$OPENCLAW_STATE_DIR"

# Clear stale lock files from previous container instances
find "$OPENCLAW_STATE_DIR" -name "*.lock" -type f -delete 2>/dev/null || true

if [[ -n "${OPENCLAW_CONFIG_TEMPLATE_FORCE:-}" && -f "$OPENCLAW_CONFIG_TEMPLATE" ]]; then
  echo "Refreshing config from template..."
  cp "$OPENCLAW_CONFIG_TEMPLATE" "$OPENCLAW_CONFIG_PATH"
elif [[ ! -f "$OPENCLAW_CONFIG_PATH" && -f "$OPENCLAW_CONFIG_TEMPLATE" ]]; then
  echo "Initializing config from template..."
  cp "$OPENCLAW_CONFIG_TEMPLATE" "$OPENCLAW_CONFIG_PATH"
fi

if [[ -n "${OPENCLAW_CONFIG:-}" ]]; then
  echo "Parsing OPENCLAW_CONFIG secret..."
  export NVIDIA_API_KEY="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.nvidia_api_key||"")')"
  export ANTHROPIC_API_KEY="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.anthropic_api_key||"")')"
  export OPENAI_API_KEY="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.openai_api_key||"")')"
  export GITHUB_TOKEN="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.github_token||"")')"
  export GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
  export LINEAR_API_KEY="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.linear_api_key||"")')"
  export OPENCLAW_WHATSAPP_ALLOW_FROM="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.whatsapp_phone||"")')"
  export TELEGRAM_BOT_TOKEN="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.telegram_bot_token||"")')"
  export GMAIL_USER="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.gmail_user||"")')"
  export GMAIL_PASSWORD="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.gmail_app_password||"")')"
  export GOOGLE_CLIENT_SECRET="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.google_client_secret||"")')"

  # Gateway auth token - parse from secret or generate random
  GATEWAY_TOKEN="$(node -e 'const c=JSON.parse(process.env.OPENCLAW_CONFIG||"{}"); process.stdout.write(c.gateway_token||"")')"
  if [[ -n "$GATEWAY_TOKEN" ]]; then
    export OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"
  fi
fi

# Generate gateway token if not set (required for startup)
if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  echo "Generating random gateway token..."
  export OPENCLAW_GATEWAY_TOKEN="$(node -e 'process.stdout.write(require("crypto").randomBytes(32).toString("hex"))')"
fi

if [[ -n "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  echo "Writing google_client_secret.json..."
  echo "$GOOGLE_CLIENT_SECRET" > "$OPENCLAW_STATE_DIR/google_client_secret.json"
fi

# Seed mcporter config for Linear MCP
MCPORTER_CONFIG_DIR="${HOME}/.config/mcporter"
mkdir -p "$MCPORTER_CONFIG_DIR"
if [[ -f /app/.mcp-workflows/servers.json ]]; then
  cp /app/.mcp-workflows/servers.json "$MCPORTER_CONFIG_DIR/servers.json"
fi

echo "Starting OpenClaw with command: $@"
exec "$@"
