#!/bin/bash
set -euo pipefail

# Install Docker, Docker Compose, gcloud, jq, Caddy
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install gcloud CLI
curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=/opt
export PATH="/opt/google-cloud-sdk/bin:$PATH"
# Persist gcloud in PATH for all users (SSH sessions, deploy scripts)
echo 'export PATH="/opt/google-cloud-sdk/bin:$PATH"' > /etc/profile.d/gcloud.sh
chmod +x /etc/profile.d/gcloud.sh

# Install jq and Caddy
apt-get install -y jq
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

# Format and mount the data disk
DATA_DISK="/dev/sdb"
if [[ -b "$DATA_DISK" ]] && ! blkid "$DATA_DISK" >/dev/null 2>&1; then
  mkfs.ext4 -F "$DATA_DISK"
fi
mkdir -p /data/openclaw
if ! mountpoint -q /data/openclaw; then
  echo "$DATA_DISK /data/openclaw ext4 defaults,nofail 0 2" >> /etc/fstab
  mount /data/openclaw
fi
chown -R 1000:1000 /data/openclaw

# Restore state from GCS backup if data dir is empty (fresh disk / VM recreation)
STATE_FILES=$(find /data/openclaw -maxdepth 1 -not -name 'lost+found' -not -path /data/openclaw | head -1)
if [[ -z "$STATE_FILES" ]]; then
  echo "Empty data dir detected — restoring from GCS backup..."
  gcloud storage rsync "gs://${sessions_bucket}/state-backup" /data/openclaw --recursive || echo "No backup found, starting fresh"
  chown -R 1000:1000 /data/openclaw
fi

# Create app directory
mkdir -p /opt/openclaw
cd /opt/openclaw

# Caddyfile: reverse proxy with auto-TLS
mkdir -p /etc/caddy
cat > /etc/caddy/Caddyfile << 'CADDYEOF'
${domain} {
  handle /healthz {
    respond "ok" 200
  }
  handle {
    reverse_proxy localhost:8080
  }
}
CADDYEOF

# Docker Compose (env_file provides OPENCLAW_CONFIG from .env)
cat > /opt/openclaw/docker-compose.prod.yml << 'COMPOSEEOF'
services:
  openclaw-gateway:
    image: ${image}
    restart: unless-stopped
    env_file:
      - .env
    environment:
      OPENCLAW_STATE_DIR: /data/openclaw
      OPENCLAW_CONFIG_PATH: /data/openclaw/openclaw.json
      OPENCLAW_CONFIG_TEMPLATE: /app/infra/openclaw/openclaw.json
      OPENCLAW_CONFIG_TEMPLATE_FORCE: "1"
      OPENCLAW_BRAIN_BUCKET: ${brain_bucket}
      OPENCLAW_SESSIONS_BUCKET: ${sessions_bucket}
    volumes:
      - /data/openclaw:/data/openclaw
    ports:
      - "127.0.0.1:8080:8080"
COMPOSEEOF

# Write config secret to .env so docker-compose reads it on every start/restart (jq -c for single-line JSON)
OPENCLAW_CONFIG=$(gcloud secrets versions access ${openclaw_config_secret_ver} --secret=${openclaw_config_secret} --project=${project_id} 2>/dev/null | jq -c . 2>/dev/null || echo "{}")
printf 'OPENCLAW_CONFIG=%s\n' "$OPENCLAW_CONFIG" > /opt/openclaw/.env

# Start Caddy (restart after a delay to ensure ACME/TLS certificate is obtained)
systemctl enable caddy
systemctl start caddy
# Caddy may fail TLS on first boot if DNS hasn't propagated; retry after a short delay
(sleep 30 && systemctl restart caddy) &

# ── Periodic state backup to GCS ──
cat > /opt/openclaw/backup-state.sh << 'BACKUPEOF'
#!/usr/bin/env bash
set -euo pipefail
BUCKET="${sessions_bucket}"
STATE_DIR="/data/openclaw"
DEST="gs://$${BUCKET}/state-backup"
export PATH="/opt/google-cloud-sdk/bin:$PATH"
echo "[$(date -u +%FT%TZ)] Starting state backup: $${STATE_DIR} → $${DEST}"
gcloud storage rsync "$${STATE_DIR}" "$${DEST}" \
  --recursive \
  --delete-unmatched-destination-objects \
  --exclude='lost\+found/.*'
echo "[$(date -u +%FT%TZ)] State backup complete"
BACKUPEOF
chmod +x /opt/openclaw/backup-state.sh

# systemd service unit
cat > /etc/systemd/system/openclaw-backup.service << 'SVCEOF'
[Unit]
Description=Backup OpenClaw state to GCS
After=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/openclaw/backup-state.sh
StandardOutput=journal
StandardError=journal
SVCEOF

# systemd timer: every 6 hours
cat > /etc/systemd/system/openclaw-backup.timer << 'TMREOF'
[Unit]
Description=Run OpenClaw state backup every 6 hours

[Timer]
OnBootSec=15min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
TMREOF

systemctl daemon-reload
systemctl enable --now openclaw-backup.timer

# Start OpenClaw container (OPENCLAW_CONFIG from host env)
cd /opt/openclaw
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

echo "OpenClaw gateway startup complete"
