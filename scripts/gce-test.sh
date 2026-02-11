#!/usr/bin/env bash
set -euo pipefail

# Test the deployed OpenClaw gateway on GCE VM (health + channel status with probe).
# Run after deployment and after WhatsApp (or other) auth.
VM_NAME="${1:-openclaw-gateway}"
ZONE="${2:-us-west1-b}"
PROJECT_ID="${3:-fin45-483402}"

echo "Testing GCE VM: $VM_NAME ($ZONE)"
echo ""

echo "=== Gateway health + channel status (--probe) ==="
gcloud compute ssh "$VM_NAME" \
  --zone "$ZONE" \
  --project "$PROJECT_ID" \
  --command "docker exec \$(docker ps -q -f name=openclaw-gateway) openclaw channels status --probe"
