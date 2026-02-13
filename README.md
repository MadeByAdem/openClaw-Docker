# openClaw Docker

Run [OpenClaw](https://openclaw.com) on your own server using Docker — no custom code, no modifications. This repository provides a ready-to-use Docker setup with Chromium browser support included.

> **What is OpenClaw?** OpenClaw is an open-source AI assistant that connects to messaging platforms like WhatsApp, Telegram and Discord. This repository lets you self-host it in a Docker container on any Linux server.

---

## Table of Contents

- [What's Included](#whats-included)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Connecting Channels](#connecting-channels)
- [Managing Your Server](#managing-your-server)
- [Troubleshooting](#troubleshooting)
- [File Overview](#file-overview)
- [Data & Backups](#data--backups)
- [License](#license)

---

## What's Included

This project adds a thin Docker layer on top of the official `alpine/openclaw` image:

- **Chromium browser** with all required dependencies for browser automation skills
- A `--no-sandbox` wrapper so Chromium runs correctly inside Docker
- Execute-permission fixes for bundled skill scripts

Everything else is standard OpenClaw — no custom code.

---

## Prerequisites

Before you start, make sure you have:

1. **A Linux server** (Ubuntu recommended, Raspberry Pi also works)
2. **Docker Engine + Docker Compose v2** installed on that server
3. **An API key** from an AI provider (e.g. [Anthropic](https://console.anthropic.com/), [OpenAI](https://platform.openai.com/))

### Installing Docker (if you don't have it yet)

If Docker is not yet installed on your server, run these commands:

```bash
# Install Docker
curl -fsSL https://get.docker.com | sudo sh

# Allow your user to run Docker without sudo
sudo usermod -aG docker $USER

# Log out and back in for the group change to take effect
exit
```

After logging back in, verify it works:

```bash
docker --version
docker compose version
```

Both commands should print a version number without errors.

---

## Installation

Follow these steps one by one. Each step includes the exact command to run.

### Step 1 — Clone this repository

```bash
git clone https://github.com/MadeByAdem/openClaw-Docker.git
cd openClaw-Docker
```

### Step 2 — Run the setup script

```bash
chmod +x setup.sh
sudo ./setup.sh
```

The setup script will automatically:

1. Check that Docker and Docker Compose are installed
2. Create the required data directories (`./data/config` and `./data/workspace`)
3. Generate a `.env` file with a secure gateway token
4. Build the Docker image
5. Start the interactive onboarding process

### Step 3 — Complete the onboarding

The onboarding wizard will start automatically. It will ask you to:

1. **Enter your AI provider API key** (e.g. your Anthropic or OpenAI key)
2. **Connect your first messaging channel** (WhatsApp, Telegram or Discord)

Follow the prompts on screen. When it's done, your OpenClaw gateway will be running.

### Step 4 — Verify it's running

```bash
docker compose logs -f openclaw-gateway
```

You should see log output indicating the gateway is active. Press `Ctrl+C` to stop following the logs (the gateway keeps running in the background).

---

## Connecting Channels

You can connect one or more messaging platforms after setup.

### WhatsApp

```bash
docker compose run --rm openclaw-cli channels login
```

A QR code will appear in your terminal. Scan it with WhatsApp on your phone to link the bot.

### Telegram

1. Create a bot via [@BotFather](https://t.me/BotFather) on Telegram and copy the bot token.
2. Add the bot:

```bash
docker compose run --rm openclaw-cli channels add --channel telegram --token "YOUR_BOT_TOKEN"
```

3. Send a message to your bot on Telegram. It will ask you to approve the pairing:

```bash
docker compose run --rm openclaw-cli pairing approve telegram CODE
```

Replace `CODE` with the pairing code shown in the message.

> **Webhook conflict?** If the bot was previously used in another project, you may need to remove the old webhook first:
>
> ```bash
> curl -s "https://api.telegram.org/botYOUR_BOT_TOKEN/deleteWebhook"
> docker compose restart openclaw-gateway
> ```
>
> Alternatively, create a fresh bot via @BotFather.

### Discord

1. Create a bot on the [Discord Developer Portal](https://discord.com/developers/applications) and copy the bot token.
2. Add the bot:

```bash
docker compose run --rm openclaw-cli channels add --channel discord --token "YOUR_BOT_TOKEN"
```

---

## Managing Your Server

Common commands for managing your OpenClaw instance:

| Action | Command |
| --- | --- |
| View live logs | `docker compose logs -f openclaw-gateway` |
| Stop the server | `docker compose down` |
| Start the server | `docker compose up -d` |
| Restart the server | `docker compose restart openclaw-gateway` |
| Change configuration | `docker compose run --rm openclaw-cli configure` |
| Rebuild after updates | `docker compose down && docker compose build --no-cache && docker compose up -d` |
| Run a security audit | `docker compose run --rm openclaw-cli security audit --deep` |

---

## Troubleshooting

### "Unknown model" error

If you see `Unknown model: anthropic/claude-sonnet-4`, the configured model name is outdated. Update it:

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

### Skill installation fails (EACCES permission error)

Some skills may fail to install during onboarding due to permissions. Fix it with:

```bash
docker compose run --rm --user root openclaw-cli npm install -g clawhub
```

### Container won't start

Check if Docker is running:

```bash
sudo systemctl status docker
```

If it's not active, start it:

```bash
sudo systemctl start docker
```

Then try again:

```bash
docker compose up -d
```

---

## File Overview

| File | Description |
| --- | --- |
| `docker-compose.yaml` | Defines the gateway and CLI services |
| `Dockerfile` | Extends the official OpenClaw image with Chromium |
| `.env.example` | Template for environment variables |
| `setup.sh` | Automated setup script (run once) |

---

## Data & Backups

All persistent data is stored in the `./data/` directory:

```
data/
├── config/       # OpenClaw configuration, API keys, memory
└── workspace/    # Files created by the AI assistant
```

**To back up your instance**, simply copy the entire `data/` directory:

```bash
cp -r ./data ./data-backup-$(date +%Y%m%d)
```

**To restore**, stop the server, replace the `data/` directory with your backup, and start again.

---

## License

This project is licensed under the [MIT License](LICENSE) — free to use, modify and distribute.
