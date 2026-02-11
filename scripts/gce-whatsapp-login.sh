#!/usr/bin/env bash
set -euo pipefail

# Run WhatsApp QR login on the GCE VM.
VM_NAME="${1:-openclaw-gateway}"
ZONE="${2:-us-west1-b}"
PROJECT_ID="${3:-fin45-483402}"

echo "Starting WhatsApp QR login on GCE VM: $VM_NAME ($ZONE)"
echo "If prompted, scan the QR code from WhatsApp > Linked Devices."

gcloud compute ssh -t "$VM_NAME" \
  --zone "$ZONE" \
  --project "$PROJECT_ID" \
  --command "docker exec -it \$(docker ps -q -f name=openclaw-gateway) openclaw channels login"
