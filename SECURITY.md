# 🔒 Security Policy

> [!CAUTION]
> ## ⛔🔴 Security Warning — Read Before Use
> **OpenClaw is still new and actively in development.** The creators themselves and independent security researchers warn about significant security risks:
>
> - 🔓 [Aikido](https://www.aikido.dev/blog/why-trying-to-secure-openclaw-is-ridiculous) — *"Why trying to secure OpenClaw is ridiculous"*
> - 🏢 [Microsoft](https://www.microsoft.com/en-us/security/blog/2026/02/19/running-openclaw-safely-identity-isolation-runtime-risk/) — *"Run OpenClaw only in fully isolated environments"*
> - 🌐 [Cisco](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare) — *"Personal AI agents like OpenClaw are a security nightmare"*
>
> **⚠️ A completely secure setup is not currently achievable.** Despite the hardening measures in this repository, **you remain fully responsible** for evaluating the risks of running OpenClaw in your environment. Do not run it on machines with access to sensitive data without understanding the implications.

---

## 📋 Scope

This repository provides a Docker wrapper around the official [OpenClaw](https://github.com/openclaw/openclaw) image. Security issues may originate from:

| Source | Examples |
| --- | --- |
| **This repository** | Docker configuration, setup scripts, documentation |
| **Upstream OpenClaw** | The OpenClaw application itself |

---

## 🚨 Reporting a Vulnerability

### This repository

If you find a security issue in the Docker configuration, setup scripts or documentation in this repository, please open a [GitHub issue](https://github.com/MadeByAdem/openClaw-Docker/issues) or contact the maintainer directly.

### Upstream OpenClaw

For vulnerabilities in the OpenClaw application itself, report them to the upstream project: [OpenClaw Security](https://github.com/openclaw/openclaw/blob/main/SECURITY.md)

---

## 🛡️ Hardening Measures

This Docker setup includes the following security measures:

### Docker container hardening

| Measure | Description |
| --- | --- |
| 🔏 **Read-only filesystem** | Prevents runtime modification of application files |
| 🚫 **All capabilities dropped** | `cap_drop: ALL` removes all Linux capabilities |
| ⬆️ **No privilege escalation** | `no-new-privileges` prevents gaining permissions |
| 📊 **Resource limits** | Memory, CPU, and PID caps prevent exhaustion and fork-bombs |
| 🏠 **Localhost-only binding** | Gateway is not exposed to the internet |
| 🔑 **Token authentication** | 256-bit hex token required for access |
| 🛡️ **Auth rate limiting** | Brute-force protection (10 attempts/min, 5-min lockout) |
| 💓 **Health checks** | Auto-detect and restart unhealthy containers |
| 🌐 **Isolated network** | Dedicated Docker bridge network |
| 🔐 **Restricted `.env`** | `chmod 600` applied during setup |
| 🩺 **Auto auditing** | `doctor --repair` and `security audit` run during setup |
| 🚫 **`.dockerignore`** | Prevents secrets from leaking into the build |

### Application-level hardening

These settings are applied to `openclaw.json` by the setup script:

| Setting | Value | Description |
| --- | --- | --- |
| 👤 **Session isolation** | `session.dmScope: "per-channel-peer"` | Each sender gets their own isolated session — prevents cross-user context leakage |
| 🚫 **Tool deny list** | `tools.deny: ["sessions_spawn", "sessions_send"]` | Blocks session hijacking tools |
| ⚙️ **Exec enabled** | `tools.exec.security: "full"` | Allows command execution (for custom scripts) |
| 📁 **Workspace-only FS** | `tools.fs.workspaceOnly: true` | Restricts file access to workspace directory only |
| 🌐 **SSRF protection** | `browser.ssrfPolicy.dangerouslyAllowPrivateNetwork: false` | Blocks browser access to private/internal networks |
| 📝 **Log redaction** | `logging.redactSensitive: "tools"` | Redacts tokens and secrets from log output |
| 📡 **mDNS disabled** | `discovery.mdns.mode: "off"` | Disables network broadcast (prevents leaking hostname and install path) |

> [!CAUTION]
> ⚠️ **Command execution is enabled by default** (`tools.exec.security: "full"`). This allows the AI to run scripts and commands on your server. If you don't need this capability, set it to `"deny"` in `./data/config/openclaw.json` to fully disable command execution. See [README.md](README.md#-security) for details on using `"allowlist"` mode as a safer middle ground.

### Enabling custom scripts (allowlist mode)

If you need the bot to run custom scripts (e.g. checking email, querying databases, sending notifications), you can use `allowlist` mode instead of `deny`. This is a middle ground between fully locked down and fully open:

| Mode | Risk level | What it allows |
| --- | --- | --- |
| `"deny"` | 🟢 Lowest | No command execution at all |
| `"allowlist"` | 🟡 Medium | Only pre-approved commands in trusted directories |
| `"full"` | 🔴 Highest | Any command — the AI has full shell access |

**Recommended approach:** use `allowlist` with `safeBinTrustedDirs` to restrict execution to a specific scripts directory:

```json
"exec": {
  "security": "allowlist",
  "safeBins": ["bash"],
  "safeBinTrustedDirs": ["/home/node/.openclaw/scripts"]
}
```

> [!WARNING]
> Enabling script execution requires removing `group:runtime` from the `tools.deny` list and removing or changing `tools.profile: "messaging"`. This expands the attack surface. Mitigate the risk by:
>
> - Keeping `safeBinTrustedDirs` as narrow as possible (only your scripts directory)
> - Reviewing all scripts for command injection vulnerabilities before placing them in the directory
> - Keeping `tools.fs.workspaceOnly: true` to limit file access
> - Using `"allowlist"` mode — never `"full"` — unless you fully understand the implications
>
> See [README.md](README.md#-security) for the full configuration example.

---

## ✅ Recommended Practices

- 🔄 Keep your installation up to date (see [Updating](README.md#-updating))
- 🔑 Rotate your gateway token periodically
- 🩺 Run `docker compose run --rm openclaw-cli security audit --deep` regularly
- 🌍 Never expose the gateway to a public IP — use SSH tunnels or Tailscale
- ⚠️ Review skill source code before installing from ClawHub
- 💾 Back up your `./data/` directory before making changes

> [!WARNING]
>
> ### 🔐 HTTPS is required for remote access
>
> If you expose the dashboard beyond localhost via a reverse proxy (Nginx, Caddy, Traefik), **you must enforce HTTPS**. Without HTTPS, your gateway token is sent in plaintext over the network, allowing attackers to intercept it.
>
> - **Always** use a TLS certificate (e.g. Let's Encrypt via Caddy or Certbot)
> - Configure your reverse proxy to automatically redirect HTTP traffic to HTTPS
> - Combine HTTPS with IP whitelisting or VPN for additional protection
> - See the [OpenClaw remote access docs](https://docs.openclaw.ai/gateway/remote) for configuration examples

---

## 📚 References

| Source | Topic |
| --- | --- |
| [Aikido](https://www.aikido.dev/blog/why-trying-to-secure-openclaw-is-ridiculous) | Security architecture analysis |
| [Microsoft](https://www.microsoft.com/en-us/security/blog/2026/02/19/running-openclaw-safely-identity-isolation-runtime-risk/) | Identity isolation and runtime risk |
| [Cisco](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare) | Skill marketplace risks |
| [Infosecurity Magazine](https://www.infosecurity-magazine.com/news/researchers-six-new-openclaw/) | Endor Labs: 6 new vulnerabilities |
| [Bitsight](https://www.bitsight.com/blog/openclaw-ai-security-risks-exposed-instances) | Exposed instances in sensitive sectors |
| [Trend Micro](https://www.trendmicro.com/en_us/research/26/b/openclaw-skills-used-to-distribute-atomic-macos-stealer.html) | Atomic macOS Stealer via skills |
| [University of Toronto](https://security.utoronto.ca/advisories/openclaw-vulnerability-notification/) | CVE-2026-25253 advisory |
| [GBHackers](https://gbhackers.com/openclaw-2026-2-12-released/) | 40+ security fixes in v2026.2.12 |
| [OpenClaw Docs](https://docs.openclaw.ai/gateway/security) | Security configuration reference |
| [OpenClaw Docs](https://docs.openclaw.ai/gateway/doctor) | Built-in config auditing |
| [OpenClaw Docs](https://docs.openclaw.ai/gateway/remote) | Secure remote access |
