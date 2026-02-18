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

# --- Ensure bind mode is set to "lan" for Docker networking ---
CONFIG_FILE="${OPENCLAW_CONFIG_DIR:-./data/config}/openclaw.json"
if [ -f "$CONFIG_FILE" ]; then
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)
    if config.get('bind') != 'lan':
        config['bind'] = 'lan'
        with open('$CONFIG_FILE', 'w') as f:
            json.dump(config, f, indent=2)
        print('[OK] Set bind mode to \"lan\" in openclaw.json')
    else:
        print('[OK] Bind mode already set to \"lan\"')
except Exception as e:
    print(f'[!]  Could not update bind mode: {e}', file=sys.stderr)
"
  else
    echo "[!]  python3 not found, skipping bind mode fix."
    echo "     If the gateway fails, manually set \"bind\": \"lan\" in $CONFIG_FILE"
  fi
fi

# --- Start the gateway ---
echo ""
echo "Starting gateway..."
docker compose up -d openclaw-gateway

# --- Verify the gateway started successfully ---
echo ""
echo "Waiting for gateway to start..."
RETRIES=10
HEALTHY=false
for i in $(seq 1 $RETRIES); do
  sleep 3
  STATUS=$(docker inspect --format='{{.State.Status}}' openclaw-gateway 2>/dev/null || echo "missing")
  HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' openclaw-gateway 2>/dev/null || echo "unknown")

  if [ "$STATUS" = "running" ]; then
    if [ "$HEALTH" = "healthy" ] || [ "$HEALTH" = "none" ] || [ "$HEALTH" = "starting" ]; then
      # Check if container is still running after a brief moment (not crash-looping)
      if [ "$i" -ge 3 ]; then
        HEALTHY=true
        break
      fi
    fi
    if [ "$HEALTH" = "unhealthy" ]; then
      echo "[!]  Gateway health check failed (attempt $i/$RETRIES)..."
    fi
  elif [ "$STATUS" = "restarting" ]; then
    echo "[!]  Gateway is restarting (attempt $i/$RETRIES)..."
  else
    echo "[!]  Gateway status: $STATUS (attempt $i/$RETRIES)..."
  fi
done

if [ "$HEALTHY" = true ]; then
  echo ""
  echo "============================================"
  echo " OpenClaw is running on 127.0.0.1:18789"
  echo "============================================"
else
  echo ""
  echo "============================================"
  echo " [!] Gateway may not have started correctly"
  echo "============================================"
  echo ""
  echo " Check the logs for errors:"
  echo "   docker compose logs openclaw-gateway"
  echo ""
  echo " Common fixes:"
  echo "   - Verify your API key is correct"
  echo "   - Check data directory permissions: sudo chown -R 1000:1000 ./data"
  echo "   - Rebuild the image: docker compose build --no-cache"
  echo "   - Re-run onboarding: docker compose run --rm openclaw-cli onboard"
fi
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
echo "============================================"
