#!/usr/bin/env bash
set -euo pipefail

# One-time migration from GCP Secret Manager OPENCLAW_CONFIG JSON
# into a standard local OpenClaw setup (~/.openclaw).
#
# Usage:
#   PROJECT_ID=fin45-483402 OPENCLAW_CONFIG_SECRET=openclaw-config bash infra/openclaw/migrate-secrets.sh

PROJECT_ID="${PROJECT_ID:-fin45-483402}"
OPENCLAW_CONFIG_SECRET="${OPENCLAW_CONFIG_SECRET:-openclaw-config}"
OPENCLAW_CONFIG_SECRET_VER="${OPENCLAW_CONFIG_SECRET_VER:-latest}"
OPENCLAW_USER="${OPENCLAW_USER:-${SUDO_USER:-${USER:-}}}"
DEFAULT_HOME="$(getent passwd "${OPENCLAW_USER}" | cut -d: -f6 || true)"
OPENCLAW_HOME="${OPENCLAW_HOME:-${DEFAULT_HOME:-/home/${OPENCLAW_USER}}}"
STATE_DIR="${OPENCLAW_STATE_DIR:-${OPENCLAW_HOME}/.openclaw}"
ENV_FILE="${STATE_DIR}/.env"

if [[ -z "${OPENCLAW_USER}" || "${OPENCLAW_USER}" == "root" ]]; then
  echo "Run this script as your normal OpenClaw user (or pass OPENCLAW_USER=...)."
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI is required but not installed."
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed."
  exit 1
fi
if ! command -v openclaw >/dev/null 2>&1; then
  echo "openclaw CLI is required but not installed."
  exit 1
fi

install -d -m 0700 "${STATE_DIR}"
touch "${ENV_FILE}"
chmod 0600 "${ENV_FILE}"
chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${STATE_DIR}" "${ENV_FILE}"

tmp_secret_json="$(mktemp)"
cleanup() {
  rm -f "${tmp_secret_json}"
}
trap cleanup EXIT

echo "Fetching OPENCLAW_CONFIG from Secret Manager..."
gcloud secrets versions access "${OPENCLAW_CONFIG_SECRET_VER}" \
  --secret="${OPENCLAW_CONFIG_SECRET}" \
  --project="${PROJECT_ID}" > "${tmp_secret_json}"

if ! jq empty "${tmp_secret_json}" >/dev/null 2>&1; then
  echo "Secret payload is not valid JSON."
  exit 1
fi

read_secret() {
  local key="$1"
  jq -r --arg key "${key}" '.[$key] // ""' "${tmp_secret_json}"
}

upsert_env() {
  local key="$1"
  local value="$2"
  [[ -z "${value}" ]] && return 0

  local escaped
  escaped="$(printf '%s' "${value}" | sed -e 's/[\/&]/\\&/g')"

  if rg -n "^${key}=" "${ENV_FILE}" >/dev/null 2>&1; then
    sed -i'' -e "s/^${key}=.*/${key}=${escaped}/" "${ENV_FILE}"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${ENV_FILE}"
  fi
}

set_config_string() {
  local path="$1"
  local value="$2"
  [[ -z "${value}" ]] && return 0
  if [[ "${EUID}" -eq 0 ]]; then
    sudo -u "${OPENCLAW_USER}" openclaw config set "${path}" "${value}"
  else
    openclaw config set "${path}" "${value}"
  fi
}

echo "Migrating environment secrets into ${ENV_FILE}..."
upsert_env "ANTHROPIC_API_KEY" "$(read_secret anthropic_api_key)"
upsert_env "OPENAI_API_KEY" "$(read_secret openai_api_key)"
upsert_env "NVIDIA_API_KEY" "$(read_secret nvidia_api_key)"
upsert_env "GITHUB_TOKEN" "$(read_secret github_token)"
upsert_env "GH_TOKEN" "$(read_secret github_token)"
upsert_env "LINEAR_API_KEY" "$(read_secret linear_api_key)"
upsert_env "GOG_ACCOUNT" "$(read_secret gog_account)"
upsert_env "GMAIL_USER" "$(read_secret gmail_user)"
upsert_env "GMAIL_PASSWORD" "$(read_secret gmail_app_password)"

echo "Migrating OpenClaw config values..."
set_config_string "gateway.auth.token" "$(read_secret gateway_token)"
set_config_string "channels.telegram.botToken" "$(read_secret telegram_bot_token)"
set_config_string "channels.telegram.webhookSecret" "$(read_secret telegram_webhook_secret)"
if [[ "${EUID}" -eq 0 ]]; then
  sudo -u "${OPENCLAW_USER}" openclaw config set channels.telegram.enabled true --json
else
  openclaw config set channels.telegram.enabled true --json
fi

service_account_key="$(read_secret service_account_key)"
if [[ -n "${service_account_key}" ]]; then
  sa_path="${STATE_DIR}/service_account_key.json"
  printf '%s\n' "${service_account_key}" > "${sa_path}"
  chmod 0600 "${sa_path}"
  chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${sa_path}"
  upsert_env "GOOGLE_APPLICATION_CREDENTIALS" "${sa_path}"
fi

google_client_secret="$(read_secret google_client_secret)"
if [[ -n "${google_client_secret}" ]]; then
  gcs_path="${STATE_DIR}/google_client_secret.json"
  printf '%s\n' "${google_client_secret}" > "${gcs_path}"
  chmod 0600 "${gcs_path}"
  chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${gcs_path}"
fi

echo "Secret migration complete."
echo "Next: run 'openclaw doctor' as ${OPENCLAW_USER}."
