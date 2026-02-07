#!/usr/bin/env bash
set -euo pipefail

BUCKET="${OPENCLAW_BRAIN_BUCKET:-}"
if [[ -z "$BUCKET" ]]; then
  echo "Set OPENCLAW_BRAIN_BUCKET before running." >&2
  exit 1
fi

ROOT="/app/infra/openclaw/brain"

node scripts/gcs-memory.mjs write prompts/active/SOUL.md --file "$ROOT/prompts/active/SOUL.md"
node scripts/gcs-memory.mjs write prompts/active/AGENTS.md --file "$ROOT/prompts/active/AGENTS.md"
node scripts/gcs-memory.mjs write prompts/active/TOOLS.md --file "$ROOT/prompts/active/TOOLS.md"
node scripts/gcs-memory.mjs write memory/long-term/preferences.md --file "$ROOT/memory/long-term/preferences.md"
node scripts/gcs-memory.mjs write instructions/HEARTBEAT.md --file "$ROOT/instructions/HEARTBEAT.md"
node scripts/gcs-memory.mjs write experiments/config.json --file "$ROOT/experiments/config.json"

echo "Brain bucket initialized: $BUCKET"
