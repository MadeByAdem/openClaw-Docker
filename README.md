# openClaw

Run [OpenClaw](https://openclaw.com) in Docker on an Ubuntu VPS (should also work on a Raspberry Pi). No modifications or custom code — just a working Docker setup with Chromium browser support out of the box.

## What's included

The [Dockerfile](Dockerfile) extends the official `alpine/openclaw` image with:

- **Chromium** and all its dependencies for browser automation skills
- A `--no-sandbox` wrapper so Chromium runs properly inside Docker
- Execute permission fixes for bundled skill scripts

## Prerequisites

- Ubuntu server (or similar) with Docker Engine + Compose v2
- API key from an AI provider (Anthropic, OpenAI, etc.)

## Quick start

### 1. Clone the repo

```bash
git clone https://github.com/<you>/openClaw.git
cd openClaw
```

### 2. Create your `.env` file

```bash
cp .env.example .env
```

### 3. Run setup

```bash
chmod +x setup.sh
sudo ./setup.sh
```

The script handles everything: creates data directories, generates a gateway token, builds the Docker image, runs onboarding, and starts the gateway.

Once it's running, the onboarding will walk you through connecting an AI provider and your first channel (Telegram, WhatsApp, Discord, etc.).

## After setup

Many OpenClaw skills (browser automation, cron jobs, email, etc.) can only be configured once the basics are running. You don't need to edit config files for this — just ask the AI assistant through your connected channel and it will set things up for you.

## Files

| File | Purpose |
| --- | --- |
| `docker-compose.yaml` | Gateway + CLI service definitions |
| `Dockerfile` | Custom image (Chromium + fixes) |
| `.env.example` | Template for configuration |
| `setup.sh` | Automated setup script |

## Adding channels

```bash
# WhatsApp
docker compose run --rm openclaw-cli channels login

# Telegram
docker compose run --rm openclaw-cli channels add --channel telegram --token "<bot-token>"

# Discord
docker compose run --rm openclaw-cli channels add --channel discord --token "<bot-token>"
```

### Telegram pairing

On first contact the bot will request pairing. Approve with:

```bash
docker compose run --rm openclaw-cli pairing approve telegram <CODE>
```

### Telegram webhook conflict

If the bot already has a webhook from another project:

```bash
wget -qO- "https://api.telegram.org/bot<BOT_TOKEN>/deleteWebhook"
docker compose restart openclaw-gateway
```

Or create a new bot via @BotFather if you want to keep the webhook for the other project.

## Troubleshooting

### Model not found

If you get `Unknown model: anthropic/claude-sonnet-4`, update the model in the config:

```bash
docker compose exec openclaw-gateway sed -i \
  's|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4-5|g' \
  /home/node/.openclaw/openclaw.json
docker compose restart openclaw-gateway
```

Available Anthropic models:

- `anthropic/claude-opus-4-5`
- `anthropic/claude-sonnet-4-5`
- `anthropic/claude-haiku-4-5`

### Skill installation fails (EACCES)

Some skills fail during onboarding due to permissions. Fix after setup:

```bash
docker compose run --rm --user root openclaw-cli npm install -g clawhub
```

## Management

```bash
# View logs
docker compose logs -f openclaw-gateway

# Stop
docker compose down

# Start
docker compose up -d

# Rebuild after Dockerfile changes
docker compose down && docker compose build --no-cache && docker compose up -d

# Change configuration
docker compose run --rm openclaw-cli configure

# Security audit
docker compose run --rm openclaw-cli security audit --deep
```

## Data

All persistent data is stored in `./data/`:

```text
data/
├── config/         # ~/.openclaw — configuration, API keys, memory
└── workspace/      # Files the agent works with
```

Backup = copy the `data/` directory.
