#!/usr/bin/env bash
set -euo pipefail

# ============================================
# OpenClaw Docker Setup
# ============================================

echo "=== OpenClaw Docker Setup ==="
echo ""

# --- Check Docker is available ---
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker is not installed."
  echo "Install Docker first: https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker compose version &>/dev/null; then
  echo "ERROR: Docker Compose v2 is not available."
  echo "Install Docker Compose: https://docs.docker.com/compose/install/"
  exit 1
fi

echo "[OK] Docker and Docker Compose found"

# --- Create data directories ---
mkdir -p ./data/config
mkdir -p ./data/workspace

# Ensure the node user (uid 1000) has write permissions
chown -R 1000:1000 ./data 2>/dev/null || {
  echo "[!]  Could not change ownership to uid 1000."
  echo "     Run this script as root, or manually run:"
  echo "     sudo chown -R 1000:1000 ./data"
}

echo "[OK] Data directories created (./data/config, ./data/workspace)"

# --- Create .env from template if it doesn't exist ---
ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  if [ -f ".env.example" ]; then
    cp .env.example "$ENV_FILE"
    echo "[OK] Created .env from .env.example"
  else
    echo "ERROR: No .env or .env.example found."
    exit 1
  fi
fi

CURRENT_TOKEN=$(grep -oP '(?<=OPENCLAW_GATEWAY_TOKEN=).+' "$ENV_FILE" 2>/dev/null || true)

if [ -z "$CURRENT_TOKEN" ]; then
  TOKEN=$(openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")
  sed -i "s/^OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=${TOKEN}/" "$ENV_FILE"
  echo "[OK] Gateway token generated"
else
  echo "[OK] Gateway token already exists"
fi

# --- Build custom image ---
echo ""
echo "Building custom image..."
docker compose build
echo "[OK] Image built"

# --- Onboarding ---
echo ""
echo "Starting onboarding..."
echo "(Follow the steps to configure your AI provider and channels)"
echo ""
docker compose run --rm openclaw-cli onboard

# --- Patch openclaw.json for Docker networking + dashboard access ---
CONFIG_FILE="${OPENCLAW_CONFIG_DIR:-./data/config}/openclaw.json"
GATEWAY_TOKEN=$(grep -oP '(?<=OPENCLAW_GATEWAY_TOKEN=).+' "$ENV_FILE")

if [ -f "$CONFIG_FILE" ]; then
  python3 -c "
import json, sys

with open('$CONFIG_FILE') as f:
    cfg = json.load(f)

gw = cfg.setdefault('gateway', {})

# Bind to LAN so Docker port-forwarding works (loopback blocks it)
gw['bind'] = 'lan'

# Sync the gateway token from .env into the config file
gw.setdefault('auth', {})['mode'] = 'token'
gw['auth']['token'] = '$GATEWAY_TOKEN'

# Trust Docker internal networks so reverse proxies (Cloudflare, nginx) work
gw['trustedProxies'] = ['172.16.0.0/12']

# Allow the dashboard to work over HTTP (needed for reverse proxy setups)
gw['controlUi'] = {'allowInsecureAuth': True}

with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
" && echo "[OK] Gateway config patched (bind=lan, trustedProxies, dashboard access)" \
  || echo "[!]  Could not patch gateway config. You may need to edit openclaw.json manually."
else
  echo "[!]  Config file not found at $CONFIG_FILE — skipping gateway patch."
  echo "     The onboarding wizard may not have created it yet."
fi

# --- Start the gateway ---
echo ""
echo "Starting gateway..."
docker compose up -d openclaw-gateway

echo ""
echo "============================================"
echo " OpenClaw is running on 127.0.0.1:18789"
echo "============================================"
echo ""
echo " Dashboard: http://127.0.0.1:18789/#token=${GATEWAY_TOKEN}"
echo ""
echo " Gateway token is stored in .env"
echo ""
echo " Useful commands:"
echo "   docker compose logs -f openclaw-gateway    # View logs"
echo "   docker compose down                        # Stop"
echo "   docker compose up -d                       # Start"
echo ""
echo " Add channels:"
echo "   docker compose run --rm openclaw-cli channels login                              # WhatsApp"
echo "   docker compose run --rm openclaw-cli channels add --channel telegram --token T   # Telegram"
echo "   docker compose run --rm openclaw-cli channels add --channel discord --token T    # Discord"
echo ""
echo " Remote dashboard (via reverse proxy):"
echo "   https://your-domain.com/#token=${GATEWAY_TOKEN}"
echo "   See README.md for reverse proxy setup instructions."
echo "============================================"
