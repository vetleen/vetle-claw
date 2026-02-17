FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Install jq, ripgrep (rg), gosu (for entrypoint to fix /data/identity ownership then run as node), and nano (editor for Fly SSH)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends jq ripgrep gosu nano && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Python 3 + requests for skills such as gemini-deep-research
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3 python3-requests && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Chromium for headless browser tool (Magda / browser control service).
# Use browser.headless: true and browser.noSandbox: true in config when running in a container (e.g. Fly).
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    chromium \
    fonts-liberation fonts-noto-color-emoji \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install gogcli (gog) for Google Workspace (Gmail/Calendar/Drive/etc.)
# Uses official GitHub release binaries + checksums verification.
ARG GOGCLI_VERSION="0.9.0"
RUN set -eux; \
    arch="linux_amd64"; \
    base="https://github.com/steipete/gogcli/releases/download/v${GOGCLI_VERSION}"; \
    file="gogcli_${GOGCLI_VERSION}_${arch}.tar.gz"; \
    curl -fsSL -o "/tmp/${file}" "${base}/${file}"; \
    curl -fsSL -o /tmp/checksums.txt "${base}/checksums.txt"; \
    (cd /tmp && grep " ${file}$" checksums.txt | sha256sum -c -); \
    tar -xzf "/tmp/${file}" -C /tmp; \
    gog_path="$(find /tmp -maxdepth 3 -type f -name gog -print -quit)"; \
    test -n "${gog_path}"; \
    install -m 0755 "${gog_path}" /usr/local/bin/gog; \
    rm -rf "/tmp/${file}" /tmp/checksums.txt /tmp/gogcli_* /tmp/gog

# Install summarize CLI for the summarize skill (Linux: npm; macOS would use brew)
RUN npm install -g @steipete/summarize

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# Optionally install Chromium and Xvfb for browser automation.
# Build with: docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 ...
# Adds ~300MB but eliminates the 60-90s Playwright install on every container start.
# Must run after pnpm install so playwright-core is available in node_modules.
ARG OPENCLAW_INSTALL_BROWSER=""
RUN if [ -n "$OPENCLAW_INSTALL_BROWSER" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
      node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY . .
RUN pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# Allow non-root user to write temp files during runtime/tests.
RUN chown -R node:node /app

# Entrypoint: remove invalid openclaw.json on boot so gateway can start with empty config (e.g. on Fly volume corruption).
RUN chmod +x /app/scripts/docker-entrypoint.sh

# Container starts as root so entrypoint can fix OPENCLAW_STATE_DIR/identity ownership
# (e.g. /data/identity on Fly) then exec as node. Main process always runs as node.
ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]

# Start gateway server with default config.
# Binds to loopback (127.0.0.1) by default for security.
#
# For container platforms requiring external health checks:
#   1. Set OPENCLAW_GATEWAY_TOKEN or OPENCLAW_GATEWAY_PASSWORD env var
#   2. Override CMD: ["node","openclaw.mjs","gateway","--allow-unconfigured","--bind","lan"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
