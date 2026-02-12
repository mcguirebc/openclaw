#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-}"
SECRET_NAME="${2:-openclaw-config}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 <project-id> [secret-name]" >&2
  exit 1
fi

# Schema: snake_case keys in JSON. entrypoint.sh parses these into env vars.
# See entrypoint.sh for the full list. Keys used by config template (openclaw.json):
#   gateway_token, nvidia_api_key, anthropic_api_key, openai_api_key, github_token,
#   linear_api_key, whatsapp_phone, telegram_bot_token, telegram_webhook_secret,
#   gmail_user, gmail_app_password, google_client_secret, gog_account
cat <<'EOF' >/tmp/openclaw-config.json
{
  "gateway_token": "REPLACE-with-random-32-char-or-longer-token",
  "nvidia_api_key": "nvapi-REPLACE",
  "anthropic_api_key": "sk-ant-REPLACE",
  "openai_api_key": "sk-REPLACE",
  "github_token": "ghp-REPLACE",
  "linear_api_key": "lin_api-REPLACE",
  "whatsapp_phone": "+15551234567",
  "telegram_bot_token": "REPLACE",
  "telegram_webhook_secret": "REPLACE",
  "gmail_user": "assistant@vidasight.com",
  "gmail_app_password": "abcd-efgh-ijkl-mnop",
  "google_client_secret": "{ \"installed\": { \"client_id\": \"...\", \"project_id\": \"...\", \"auth_uri\": \"...\", \"token_uri\": \"...\", \"auth_provider_x509_cert_url\": \"...\", \"client_secret\": \"...\", \"redirect_uris\": [\"http://localhost\"] } }",
  "gog_account": "assistant@vidasight.com"
}
EOF

gcloud secrets create "$SECRET_NAME" \
  --project "$PROJECT_ID" \
  --replication-policy="automatic" \
  --data-file="/tmp/openclaw-config.json"

rm -f /tmp/openclaw-config.json

echo "Created secret: $SECRET_NAME in project $PROJECT_ID"
