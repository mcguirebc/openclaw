---
name: gcs-memory
description: "Read and write versioned memory/prompt files in a GCS bucket using the metadata server credentials."
metadata:
  {
    "openclaw":
      {
        "emoji": "🧠",
        "requires": { "bins": ["node"] },
      },
  }
---

# GCS Memory Skill

Use this skill to read and write OpenClaw memory and prompt files stored in a versioned GCS bucket.

Set the bucket via `OPENCLAW_BRAIN_BUCKET` (recommended) or pass `--bucket`.

## Read a file

```bash
node scripts/gcs-memory.mjs read memory/long-term/preferences.md
```

## Write a file

```bash
node scripts/gcs-memory.mjs write memory/long-term/preferences.md --content "Updated preferences..."
```

## Upload from a local file

```bash
node scripts/gcs-memory.mjs write prompts/active/AGENTS.md --file /app/infra/openclaw/brain/prompts/active/AGENTS.md
```

## List versions

```bash
node scripts/gcs-memory.mjs versions memory/long-term/preferences.md
```

## Rollback

```bash
node scripts/gcs-memory.mjs rollback memory/long-term/preferences.md --generation 1234567890
```
