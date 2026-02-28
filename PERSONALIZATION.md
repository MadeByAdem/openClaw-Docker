# 🎨 Personalization

Make your AI agent *yours*. Run `personalize.sh` after setup to configure your agent's identity, personality, and behavior through a series of workspace files.

```bash
./personalize.sh
```

---

## 📁 The Files

### 🪪 `IDENTITY.md` — Who your agent is

Name, emoji, roles, primary language, and self-introduction. This is the first thing your agent reads to understand *what* it is.

### 💠 `SOUL.md` — How your agent thinks

Core values and communication style. Shapes the personality — casual or formal, sarcastic or supportive, opinionated or neutral. This is the *character* behind the responses.

### 👤 `USER.md` — Who you are

Your name, timezone, language, and communication preferences. The more context you give, the better your agent can adapt. Add family members, colleagues, or anyone else the agent should know about.

### 🤖 `AGENTS.md` — How your agent behaves

Session startup routine, memory management, safety rules, group chat etiquette, and tool usage guidelines. Ships with sensible defaults — customize what matters to you.

### 📐 `CONVENTIONS.md` — Your project standards

Terminology, coding standards, git workflow, and branch naming conventions. Primarily useful if your agent helps with development work. Skip if you don't code.

### 🔧 `TOOLS.md` — Your integrations

Document scripts, APIs, and credentials your agent needs. Email accounts, calendar integrations, home automation, GitHub — anything the agent should know how to use.

### 💓 `HEARTBEAT.md` — Periodic tasks

Define what your agent should check during heartbeat polls: unread emails, upcoming calendar events, weather, notifications. Leave empty to disable.

### 🧠 `MEMORY.md` — Long-term memory

Starts empty. Your agent fills this over time with things worth remembering across sessions. You can seed it with context you want the agent to always have.

---

## ⚙️ How the script works

For each file, you choose:

- **Edit** — opens your text editor (`$EDITOR`, or `nano`/`vim` fallback)
- **View example** — shows a working example based on a real agent config
- **Skip** — keeps the default template — edit later if you want

Files that need basic info (IDENTITY, SOUL, USER) ask a few quick questions first, then generate a template you can fine-tune in your editor.

After all files are configured, the script restarts OpenClaw automatically.

---

## ✍️ Editing later

All files live in `./data/workspace/`. Edit them anytime:

```bash
nano ./data/workspace/SOUL.md
docker compose restart openclaw-gateway
```

Your agent reads these files at the start of every session — changes take effect on the next conversation.
