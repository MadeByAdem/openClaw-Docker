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
- [Choosing a Model](#choosing-a-model)
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

> **Which model should I choose?** See [Choosing a Model](#choosing-a-model) below for guidance.

### Skill installation fails (EACCES permission error)

Some skills may fail to install during onboarding due to permissions. Fix it with:

```bash
docker compose run --rm --user root openclaw-cli npm install -g clawhub
```

### Health check failed: gateway closed (1006)

If you see `Health check failed: gateway closed (1006 abnormal closure)` with `Bind: loopback`, the gateway's bind mode is incorrect for Docker. The config file (`openclaw.json`) may have overridden the bind setting.

**Fix the bind mode:**

```bash
docker compose exec openclaw-gateway sed -i 's/"bind":\s*"loopback"/"bind": "lan"/g' /home/node/.openclaw/openclaw.json
docker compose restart openclaw-gateway
```

Or edit `./data/config/openclaw.json` directly and change `"bind": "loopback"` to `"bind": "lan"`, then restart:

```bash
docker compose restart openclaw-gateway
```

> **Why does this happen?** Inside a Docker container, the gateway must bind to all interfaces (`lan` / `0.0.0.0`) so Docker's port forwarding can reach it. The `loopback` setting binds only to `127.0.0.1` inside the container, making it unreachable from the host.

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

## Choosing a Model

Your choice of AI model has a direct impact on the quality of responses and your API costs. Here's what you need to know.

### Model comparison

| Model | Strengths | Cost level |
| --- | --- | --- |
| `anthropic/claude-haiku-4-5` | Fast, lightweight, good for simple tasks | Lowest |
| `anthropic/claude-sonnet-4-5` | Balanced: capable and cost-effective | Medium |
| `anthropic/claude-opus-4-5` | Most capable, best for complex reasoning | Highest |

### Recommendations

- **Start with Sonnet.** It offers the best balance between capability and cost for most use cases. This is a solid default for everyday conversations and tasks.
- **Use Haiku for high-volume, simple tasks.** If your bot handles many short interactions (quick Q&A, simple lookups), Haiku keeps costs low while still delivering good results.
- **Reserve Opus for complex work.** Opus excels at multi-step reasoning, detailed analysis and creative tasks — but it costs significantly more per message. Only use it when you genuinely need the extra capability.

### Advanced: use different models per task type

You can significantly reduce costs by routing tasks to the right model automatically. Instead of using a single model for everything, configure your assistant to:

- **Use Haiku for routine tasks** — emails, calendar queries, simple Q&A, summaries and other straightforward interactions.
- **Use Sonnet for complex tasks** — code generation, debugging, technical analysis and multi-step reasoning.

This "model routing" approach can reduce your per-session costs by 60–70%, because the majority of everyday interactions don't need the most capable (and most expensive) model.

You can set this up by defining task categories and model assignments in your OpenClaw configuration or via an `AGENTS.md` file in your workspace.

### Advanced: use Claude Code CLI for code tasks

If you frequently ask your assistant to analyze or generate code, consider offloading those tasks to [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic's CLI tool). Claude Code is optimized for coding workflows and can be more efficient than running code tasks through the chat interface, because it:

- Sends only the relevant code context instead of the full conversation history
- Uses targeted file reads instead of loading entire documents
- Avoids unnecessary overhead from chat-based interaction

You can configure OpenClaw to prioritize Claude Code CLI for code-related skills.

### Keeping costs under control

- **Monitor your API usage** through your provider's dashboard ([Anthropic Console](https://console.anthropic.com/), [OpenAI Platform](https://platform.openai.com/)). Set spending alerts and budget limits before going live.
- **Set a monthly budget limit** with your API provider to avoid surprises. Both Anthropic and OpenAI allow you to configure hard spending caps.
- **Minimize context size.** Only load documents and files when they're actually needed instead of including them in every message. This can drastically reduce the number of tokens sent per request.
- **Longer conversations cost more.** Each message in a conversation includes the full history, so costs grow as conversations get longer. Consider restarting conversations when the topic changes.
- **Use text-to-speech sparingly.** If your assistant supports TTS, configure it to only generate audio when the user sends a voice message or explicitly asks for it — not on every response.
- **Skills and tools add cost.** When the assistant uses browser automation or other skills, it generates extra API calls. Keep this in mind for automated workflows.
- **Test in low-traffic environments first.** Before connecting a busy group chat, test your setup with one or two users to get a feel for actual usage patterns and costs.

### Changing your model

You can switch models at any time via the CLI:

```bash
docker compose run --rm openclaw-cli configure
```

Or edit the configuration file directly at `./data/config/openclaw.json`.

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
