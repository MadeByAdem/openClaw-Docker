FROM alpine/openclaw

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       chromium \
       fonts-liberation \
       libasound2 \
       libatk-bridge2.0-0 \
       libatk1.0-0 \
       libatspi2.0-0 \
       libcups2 \
       libdbus-1-3 \
       libdrm2 \
       libgbm1 \
       libgtk-3-0 \
       libnspr4 \
       libnss3 \
       libwayland-client0 \
       libxcomposite1 \
       libxdamage1 \
       libxfixes3 \
       libxkbcommon0 \
       libxrandr2 \
       xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Wrapper that always starts Chromium with --no-sandbox (required in Docker)
RUN printf '#!/bin/sh\nexec /usr/bin/chromium --no-sandbox --disable-gpu --disable-dev-shm-usage "$@"\n' \
    > /usr/local/bin/chromium-docker \
    && chmod +x /usr/local/bin/chromium-docker

# Fix execute permissions on skill scripts
RUN find /app/skills -type f -name "*.sh" -exec chmod +x {} \;

ENV CHROME_BIN=/usr/local/bin/chromium-docker
USER node
