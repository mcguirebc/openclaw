#!/usr/bin/env bash
# Backup /data/openclaw state to GCS sessions bucket.
# Runs via systemd timer on the VM; can also be invoked manually.
set -euo pipefail

BUCKET="${OPENCLAW_SESSIONS_BUCKET:-openclaw-sessions-fin45-483402}"
STATE_DIR="${OPENCLAW_STATE_DIR:-/data/openclaw}"
DEST="gs://${BUCKET}/state-backup"

export PATH="/opt/google-cloud-sdk/bin:$PATH"

echo "[$(date -u +%FT%TZ)] Starting state backup: ${STATE_DIR} → ${DEST}"

# rsync local state to GCS (skip lost+found, delete remote files that no longer exist locally)
gcloud storage rsync "${STATE_DIR}" "${DEST}" \
  --recursive \
  --delete-unmatched-destination-objects \
  --exclude='lost\+found/.*'

echo "[$(date -u +%FT%TZ)] State backup complete"
