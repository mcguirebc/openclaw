#!/usr/bin/env bash
set -euo pipefail

# Idempotent setup for a native (non-Docker) OpenClaw VM.
# Usage:
#   sudo DOMAIN=gateway.note.ski PROJECT_ID=fin45-483402 SESSIONS_BUCKET=openclaw-sessions-fin45-483402 bash infra/openclaw/setup-vm.sh

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

DOMAIN="${DOMAIN:-gateway.note.ski}"
PROJECT_ID="${PROJECT_ID:-fin45-483402}"
SESSIONS_BUCKET="${SESSIONS_BUCKET:-openclaw-sessions-fin45-483402}"
OPENCLAW_USER="${OPENCLAW_USER:-${SUDO_USER:-${USER:-}}}"
DEFAULT_HOME="$(getent passwd "${OPENCLAW_USER}" | cut -d: -f6 || true)"
OPENCLAW_HOME="${OPENCLAW_HOME:-${DEFAULT_HOME:-/home/${OPENCLAW_USER}}}"
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-${OPENCLAW_HOME}/.openclaw}"
BACKUP_SCRIPT="/usr/local/bin/openclaw-backup-state.sh"
CRON_FILE="/etc/cron.d/openclaw-backup"

if [[ -z "${OPENCLAW_USER}" || "${OPENCLAW_USER}" == "root" ]]; then
  echo "OPENCLAW_USER must be a non-root Linux user."
  exit 1
fi

if [[ ! -d "${OPENCLAW_HOME}" ]]; then
  echo "Home directory does not exist: ${OPENCLAW_HOME}"
  exit 1
fi

echo "==> Installing base packages"
apt-get update
apt-get install -y ca-certificates curl gnupg jq git gh cron unzip

echo "==> Installing Node.js 22"
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | sed 's/^v//; s/\..*$//')" -lt 22 ]]; then
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update
  apt-get install -y nodejs
fi

echo "==> Installing OpenClaw CLI"
npm install -g openclaw@latest

echo "==> Installing gcloud CLI"
if ! command -v gcloud >/dev/null 2>&1; then
  install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list
  apt-get update
  apt-get install -y google-cloud-cli
fi

echo "==> Installing gog CLI"
if ! command -v gog >/dev/null 2>&1; then
  GOG_VERSION="${GOG_VERSION:-0.9.0}"
  ARCH="$(dpkg --print-architecture)"
  case "${ARCH}" in
    amd64) GOG_ARCH="amd64" ;;
    arm64) GOG_ARCH="arm64" ;;
    *)
      echo "Unsupported architecture for gog: ${ARCH}"
      exit 1
      ;;
  esac
  TMP_TAR="$(mktemp)"
  curl -fsSL "https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/gogcli_${GOG_VERSION}_linux_${GOG_ARCH}.tar.gz" -o "${TMP_TAR}"
  tar -xzf "${TMP_TAR}" -C /usr/local/bin gog
  chmod +x /usr/local/bin/gog
  rm -f "${TMP_TAR}"
fi

echo "==> Installing and configuring Caddy"
if ! command -v caddy >/dev/null 2>&1; then
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
fi

cat >/etc/caddy/Caddyfile <<EOF
${DOMAIN} {
  handle /healthz {
    respond "ok" 200
  }
  handle {
    reverse_proxy localhost:18789
  }
}
EOF
systemctl enable caddy
systemctl restart caddy

echo "==> Preparing OpenClaw state directory"
install -d -m 0750 -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" "${OPENCLAW_STATE_DIR}"
touch "${OPENCLAW_STATE_DIR}/.env"
chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${OPENCLAW_STATE_DIR}/.env"
chmod 0600 "${OPENCLAW_STATE_DIR}/.env"

echo "==> Configuring Chrome Remote Desktop prerequisites"
apt-get install -y xfce4 xfce4-goodies
if ! dpkg -s chrome-remote-desktop >/dev/null 2>&1; then
  TMP_DEB="$(mktemp --suffix=.deb)"
  curl -fsSL https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb -o "${TMP_DEB}"
  apt-get install -y "${TMP_DEB}" || apt-get -f install -y
  rm -f "${TMP_DEB}"
fi

CRD_CONF_DIR="${OPENCLAW_HOME}/.config/chrome-remote-desktop"
install -d -m 0755 -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" "${CRD_CONF_DIR}"
cat >"${CRD_CONF_DIR}/chrome-remote-desktop-session" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/xfce4-session
EOF
chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${CRD_CONF_DIR}/chrome-remote-desktop-session"
chmod 0755 "${CRD_CONF_DIR}/chrome-remote-desktop-session"
usermod -a -G chrome-remote-desktop "${OPENCLAW_USER}" || true

echo "==> Creating OpenClaw backup script and cron job"
cat >"${BACKUP_SCRIPT}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export CLOUDSDK_CORE_PROJECT="${PROJECT_ID}"
STATE_DIR="${OPENCLAW_STATE_DIR}"
DEST="gs://${SESSIONS_BUCKET}/state-backup"
mkdir -p "\${STATE_DIR}"
gcloud storage rsync "\${STATE_DIR}" "\${DEST}" \
  --recursive \
  --delete-unmatched-destination-objects
EOF
chmod 0750 "${BACKUP_SCRIPT}"
chown root:root "${BACKUP_SCRIPT}"

cat >"${CRON_FILE}" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 */6 * * * ${OPENCLAW_USER} ${BACKUP_SCRIPT} >> /var/log/openclaw-backup.log 2>&1
EOF
chmod 0644 "${CRON_FILE}"
systemctl enable cron
systemctl restart cron

echo "==> Installing OpenClaw gateway service for user ${OPENCLAW_USER}"
runuser -l "${OPENCLAW_USER}" -c "openclaw gateway install || true"

cat <<EOF

Setup complete.

Next steps:
1) Run secrets migration script.
2) Start gateway as ${OPENCLAW_USER}: openclaw gateway run --bind loopback --port 18789
3) Verify: openclaw doctor && openclaw channels status --probe
4) Finalize Chrome Remote Desktop using:
   https://remotedesktop.google.com/headless
EOF
