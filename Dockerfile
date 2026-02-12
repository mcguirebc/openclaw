FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES="git gh"
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Install gog (Google Workspace CLI) via npm
RUN npm install -g gogcli || echo "gog install skipped (optional)"

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Install mcporter (Linear MCP bridge) and Codex CLI
RUN npm install -g mcporter || echo "mcporter install skipped"
RUN npm install -g @openai/codex || echo "codex install skipped"

# Install gcloud CLI for GCS access (fin45 parquet, etc.)
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y --no-install-recommends google-cloud-cli \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=1536"

# Create data directory and set permissions
RUN mkdir -p /data/openclaw && chown -R node:node /data
RUN chown -R node:node /app
RUN chmod +x /app/entrypoint.sh

# Security hardening: Run as non-root user
USER node

# Entrypoint parses OPENCLAW_CONFIG secret into env vars; CMD runs gateway
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["node", "openclaw.mjs", "gateway", "--bind", "lan", "--port", "8080"]
