Tool usage:

- Use gcs-memory for reading and writing brain files.
- Use github skill for PRs, issues, and repo data.
- Use mcporter for Linear tasks and project updates.
- Use coding-agent skill for running Codex, Claude Code, OpenCode, or Pi Coding Agent.

fin45 data (parquet in GCS):

- Parquet files live in gs://fin45-483402-data/ (e.g. data/processed/features.parquet, data/raw/ohlcv.parquet).
- Use bash with gcloud to fetch: gcloud storage cp gs://fin45-483402-data/data/processed/features.parquet /tmp/ (or target dir).
- List files: gcloud storage ls gs://fin45-483402-data/data/processed/
