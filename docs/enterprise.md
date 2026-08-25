# Enterprise deployment — org-wide (managed)

Two layers. Both are required for a full org rollout.

| Layer | What | How |
| --- | --- | --- |
| **A. Claude managed settings** | Marketplace + force-enable plugin + TrustGate MCP URL | [`mdm/claude/managed-settings.json`](../mdm/claude/managed-settings.json) |
| **B. TrustGuard MDM** | Collector `tgk_…` + hook binary | [`mdm/kandji/`](../mdm/kandji/) |

```
┌─────────────────────────────────────────────────────────────┐
│  Claude Code managed-settings.json (every Mac / server)     │
│  · extraKnownMarketplaces.neuraltrust                       │
│  · enabledPlugins["trustguard@neuraltrust"] = true          │
│  · pluginConfigs…options.trustgate_mcp_url                  │
└───────────────────────────┬─────────────────────────────────┘
                            │ loads plugin hooks + TrustGate MCP
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  TrustGuard managed config + binary (Kandji)                │
│  · /Library/Application Support/TrustGuard/claude-code.json │
│  · …/bin/trustguard-claude-code                             │
└─────────────────────────────────────────────────────────────┘
```

## A — Claude managed settings (plugin + MCP)

Canonical template and ops notes: **[mdm/claude/README.md](../mdm/claude/README.md)**.

```json
{
  "extraKnownMarketplaces": {
    "neuraltrust": {
      "source": {
        "source": "github",
        "repo": "NeuralTrust/trustguard-claude-code-plugin"
      },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "trustguard@neuraltrust": true
  },
  "pluginConfigs": {
    "trustguard@neuraltrust": {
      "options": {
        "trustgate_mcp_url": "https://HOST/CONSUMER-SLUG/mcp"
      }
    }
  }
}
```

| Key | Role |
| --- | --- |
| `extraKnownMarketplaces` | Registers the GitHub marketplace for every user |
| `enabledPlugins` | Force **trustguard@neuraltrust** on (users cannot turn it off) |
| `pluginConfigs.*.options` | Pre-set `userConfig` MCP URL — nested under **`options`** |

**Paths (file-based):**

| OS | Path |
| --- | --- |
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux / WSL | `/etc/claude-code/managed-settings.json` |
| Windows | `C:\Program Files\ClaudeCode\managed-settings.json` |

Also valid: claude.ai **server-managed settings** (same keys) or macOS
profile domain `com.anthropic.claudecode`. Prefer **one** managed source;
remote beats file when both exist.

**Do not** use “Add custom connector” for TrustGate. That UI is unrelated to
plugin `userConfig` and shows a locked `${user_config…}` placeholder.

Auth to TrustGate is **OAuth** (URL only). Each user completes OAuth once from
`/mcp` the first time; the URL itself is org-managed.

### Kandji can write this file

On the install script:

```bash
TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS=1
TRUSTGATE_MCP_URL=https://HOST/CONSUMER-SLUG/mcp
```

## B — TrustGuard collector + binary (Kandji)

- **[mdm/kandji/README.md](../mdm/kandji/README.md)**
- `install-trustguard-claude-code.sh` / `audit-trustguard-claude-code.sh`

When `api_key` is set in the system file, the binary locks `api_key`,
`data_url`, and `fail_mode` against user file and env overrides.

| OS | Managed config |
|---|---|
| macOS | `/Library/Application Support/TrustGuard/claude-code.json` |
| Linux | `/etc/trustguard/claude-code.json` |
| Windows | `%ProgramData%\TrustGuard\claude-code.json` |

```json
{
  "data_url": "https://data.example.neuraltrust.ai",
  "api_key": "tgk_…",
  "fail_mode": "closed"
}
```

Bootstrap prefers the MDM binary over any developer `PATH` copy.

## Org checklist

- [ ] Merge this repo to the GitHub default branch the marketplace clones
- [ ] Publish GitHub **release** `vX.Y.Z` with multi-arch binaries; pin SHA-256
      in bootstrap scripts for production
- [ ] TrustGuard: Claude Code / IDE collector → `tgk_…` + data-plane URL
- [ ] TrustGate Connect: org MCP URL (`https://…/…/mcp`)
- [ ] Fill `mdm/claude/managed-settings.json` (or Kandji env vars above)
- [ ] Kandji Blueprint: install script with `tgk_…` (+ optional Claude deploy)
- [ ] Pilot Mac: `/status` shows Enterprise managed settings; `claude plugin list`
      shows `trustguard@neuraltrust`; `/mcp` OAuth; hook probe; TrustGuard
      `source.application=claude-code-plugin`
- [ ] Expand Blueprint

## Inference Hooks vs this plugin

Do **not** put Inference Hook `whsec_…` in the collector config. Use `tgk_…`.

Inference Hook traffic uses `source.application` values such as `claude-ai` /
`claude-code`. This plugin stamps `source.application=claude-code-plugin` so
policy gates can split the two paths.
