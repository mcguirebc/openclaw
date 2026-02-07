#!/usr/bin/env bash
set -euo pipefail

# Test the deployed OpenClaw gateway on Cloud Run (health + channel status with probe).
# Run after deployment and after WhatsApp (or other) auth.
SERVICE="${1:-openclaw-gateway}"
REGION="${2:-us-west1}"

echo "Testing Cloud Run service: $SERVICE ($REGION)"
echo ""

echo "=== Service URL ==="
gcloud run services describe "$SERVICE" --region "$REGION" --format 'value(status.url)' 2>/dev/null || true
echo ""

echo "=== Gateway health + channel status (--probe) ==="
gcloud run services exec "$SERVICE" \
  --region "$REGION" \
  --command "openclaw channels status --probe"
