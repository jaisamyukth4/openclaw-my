FROM node:22-bookworm

# 1. Install System Tools (Required for Mad Scientist Script & Build)
# We explicitly add 'zip' and 'unzip' here so the entrypoint script works.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl zip unzip ca-certificates git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# (Optional: User provided ARG for extra packages)
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .

# Build the application
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# --- MAD SCIENTIST & HUGGING FACE SETUP ---

# 2. Create Data Directory & Fix Permissions
# We create the folder where the "Brain" will live and ensure the 'node' user owns it.
# This prevents "Permission Denied" errors when unzipping the memory.
RUN mkdir -p /app/data && chown -R node:node /app

# 3. Copy the Mad Scientist Script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 4. Configure Hugging Face Port (Critical)
# Hugging Face Spaces ALWAYS expects Port 7860.
ENV PORT=7860
EXPOSE 7860

# 5. Switch to Non-Root User (Security)
USER node

# 6. Entrypoint & Command
# The Entrypoint runs the backup/restore logic.
ENTRYPOINT ["/entrypoint.sh"]

# The CMD starts OpenClaw.
# We added '--bind lan' to ensure it listens on 0.0.0.0 (Public) instead of 127.0.0.1 (Localhost).
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured", "--bind", "lan"]
