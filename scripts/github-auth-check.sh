#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
  echo "Missing GITHUB_TOKEN or GH_TOKEN." >&2
  exit 1
fi

export GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
gh auth status
