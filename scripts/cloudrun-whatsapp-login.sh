#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:-openclaw-gateway}"
REGION="${2:-us-west1}"

echo "Starting WhatsApp QR login in Cloud Run service: $SERVICE ($REGION)"
echo "If prompted, scan the QR code from WhatsApp > Linked Devices."

gcloud run services exec "$SERVICE" \
  --region "$REGION" \
  --command "openclaw channels login"
