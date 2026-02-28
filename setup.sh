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

# Restrict .env permissions — only the file owner can read/write
chmod 600 "$ENV_FILE"

CURRENT_TOKEN=$(grep -oP '(?<=OPENCLAW_GATEWAY_TOKEN=).+' "$ENV_FILE" 2>/dev/null || true)

if [ -z "$CURRENT_TOKEN" ]; then
  TOKEN=$(openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")
  sed -i "s/^OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=${TOKEN}/" "$ENV_FILE"
  echo "[OK] Gateway token generated and stored in .env"
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
  # Detect the Docker bridge subnet dynamically (falls back to default)
  DOCKER_SUBNET=$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "172.17.0.0/16")

  # Pass variables via environment to avoid shell-in-Python injection
  OC_CONFIG_FILE="$CONFIG_FILE" \
  OC_GATEWAY_TOKEN="$GATEWAY_TOKEN" \
  OC_DOCKER_SUBNET="$DOCKER_SUBNET" \
  OC_ALLOW_INSECURE_AUTH="${OPENCLAW_ALLOW_INSECURE_AUTH:-false}" \
  python3 -c "
import json, os

config_file = os.environ['OC_CONFIG_FILE']
gateway_token = os.environ['OC_GATEWAY_TOKEN']
docker_subnet = os.environ['OC_DOCKER_SUBNET']

with open(config_file) as f:
    cfg = json.load(f)

gw = cfg.setdefault('gateway', {})

# Bind to LAN so Docker port-forwarding works (loopback blocks it)
gw['bind'] = 'lan'

# Sync the gateway token from .env into the config file
gw.setdefault('auth', {})['mode'] = 'token'
gw['auth']['token'] = gateway_token

# Trust Docker bridge network only (detected dynamically)
gw['trustedProxies'] = [docker_subnet]

# Rate limit auth attempts to mitigate brute-force attacks
gw['auth']['rateLimit'] = {
    'maxAttempts': 10,
    'windowMs': 60000,
    'lockoutMs': 300000
}

# Dashboard auth over HTTP — disabled by default for security.
# Only enable via OPENCLAW_ALLOW_INSECURE_AUTH=true if behind a TLS-terminating reverse proxy.
allow_insecure = os.environ.get('OC_ALLOW_INSECURE_AUTH', 'false').lower() == 'true'
gw['controlUi'] = {'allowInsecureAuth': allow_insecure}

# Disable mDNS broadcast (not needed in Docker, leaks info)
cfg.setdefault('discovery', {}).setdefault('mdns', {})['mode'] = 'off'

# --- Session isolation ---
# Each sender gets their own isolated session (prevents cross-user context leakage)
cfg.setdefault('session', {})['dmScope'] = 'per-channel-peer'

# --- Tool restrictions ---
tools = cfg.setdefault('tools', {})

# Block session hijacking tools
tools['deny'] = ['sessions_spawn', 'sessions_send']

# Allow command execution (for custom scripts in ~/.openclaw/scripts/)
tools.setdefault('exec', {})['security'] = 'full'

# Restrict filesystem access to workspace only
tools.setdefault('fs', {})['workspaceOnly'] = True

# --- SSRF protection ---
# Block browser access to private/internal networks
cfg.setdefault('browser', {}).setdefault('ssrfPolicy', {})['dangerouslyAllowPrivateNetwork'] = False

# --- Logging ---
# Redact sensitive data (tokens, keys) from logs
cfg.setdefault('logging', {})['redactSensitive'] = 'tools'

with open(config_file, 'w') as f:
    json.dump(cfg, f, indent=2)
" && echo "[OK] Gateway config patched (networking, auth, session isolation, tool restrictions, SSRF protection)" \
  || echo "[!]  Could not patch gateway config. You may need to edit openclaw.json manually."
else
  echo "[!]  Config file not found at $CONFIG_FILE — skipping gateway patch."
  echo "     The onboarding wizard may not have created it yet."
fi

# --- Start the gateway ---
echo ""
echo "Starting gateway..."
docker compose up -d openclaw-gateway

# --- Run security checks ---
echo ""
echo "Running security checks..."
docker compose run --rm openclaw-cli doctor --repair 2>/dev/null \
  && echo "[OK] Doctor check passed" \
  || echo "[!]  Doctor check encountered issues — review the output above"

docker compose run --rm openclaw-cli security audit --deep 2>/dev/null \
  && echo "[OK] Security audit passed" \
  || echo "[!]  Security audit found issues — review the output above"

echo ""
echo "============================================"
echo " OpenClaw is running on 127.0.0.1:18789"
echo "============================================"
echo ""
echo " Your gateway token is stored in .env"
echo " Open the dashboard:  http://127.0.0.1:18789"
echo " (append /#token=YOUR_TOKEN — find the token in your .env file)"
echo ""
echo " Useful commands:"
echo "   docker compose logs -f openclaw-gateway    # View logs"
echo "   docker compose down                        # Stop"
echo "   docker compose up -d                       # Start"
echo ""
echo " Add channels:"
echo "   docker compose run --rm openclaw-cli plugins enable whatsapp                     # Enable WhatsApp plugin"
echo "   docker compose run --rm openclaw-cli channels login --channel whatsapp           # WhatsApp (scan QR)"
echo "   docker compose run --rm openclaw-cli channels add --channel telegram --token T   # Telegram"
echo "   docker compose run --rm openclaw-cli channels add --channel discord --token T    # Discord"
echo ""
echo " Security:"
echo "   docker compose run --rm openclaw-cli doctor --repair          # Check & fix config issues"
echo "   docker compose run --rm openclaw-cli security audit --deep    # Deep security audit"
echo ""
echo " Token rotation (recommended periodically):"
echo "   1. Generate a new token:  openssl rand -hex 32"
echo "   2. Update .env with the new token"
echo "   3. Update data/config/openclaw.json → gateway.auth.token"
echo "   4. Restart:  docker compose restart openclaw-gateway"
echo ""
echo " Remote dashboard (via reverse proxy):"
echo "   See README.md for reverse proxy and security setup."
echo "============================================"
