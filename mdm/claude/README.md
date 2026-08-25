# Claude Code managed settings — TrustGuard (org-wide)

Deploys the **plugin + TrustGate MCP URL** to every Claude Code session on the
machine. Pair with Kandji (`../kandji/`) for the collector `tgk_…` and binary.

| Layer | Delivers | Path / mechanism |
| --- | --- | --- |
| This file | marketplace, plugin enable, MCP URL | Claude `managed-settings.json` |
| Kandji | `tgk_…` + `trustguard-claude-code` binary | TrustGuard support dir |

Do **not** use “Add custom connector” for TrustGate. The plugin owns the MCP
server via `userConfig` → `${user_config.trustgate_mcp_url}`.

## 1. Fill the template

Edit [`managed-settings.json`](./managed-settings.json):

1. Replace `trustgate_mcp_url` with the org TrustGate Connect MCP endpoint  
   (`https://{host}/{consumer-slug}/mcp`).
2. Leave `enabledPlugins` / `extraKnownMarketplaces` as-is unless your
   marketplace name differs from `neuraltrust`.

Optional hardening (same file or a drop-in under `managed-settings.d/`):

```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "anthropics/claude-plugins-official" },
    { "source": "github", "repo": "NeuralTrust/trustguard-claude-code-plugin" }
  ],
  "pluginTrustMessage": "Trustguard is approved by IT for this organization."
}
```

## 2. Place on each Mac (file-based managed settings)

Official path ([managed settings](https://code.claude.com/docs/en/managed-settings)):

```
/Library/Application Support/ClaudeCode/managed-settings.json
```

| OS | Path |
| --- | --- |
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux / WSL | `/etc/claude-code/managed-settings.json` |
| Windows | `C:\Program Files\ClaudeCode\managed-settings.json` |

**Kandji:** set `TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS=1` and
`TRUSTGATE_MCP_URL=https://…` on
[`../kandji/install-trustguard-claude-code.sh`](../kandji/install-trustguard-claude-code.sh)
so the same Custom Script writes this file. Or File drop the JSON to the path
above (root-owned, mode `0644`).

**Alternatives:** claude.ai **server-managed settings** (same JSON keys, no file
on disk), or macOS configuration profile domain `com.anthropic.claudecode`.

If server-managed settings and a local file both exist, Claude Code picks **one**
source (remote wins over file). Prefer a single mechanism.

## 3. What each key does

| Key | Effect |
| --- | --- |
| `extraKnownMarketplaces.neuraltrust` | Registers GitHub marketplace `NeuralTrust/trustguard-claude-code-plugin` for every user |
| `autoUpdate: true` | Refresh marketplace + installed plugins in the background |
| `enabledPlugins["trustguard@neuraltrust"]: true` | Force plugin on; users cannot disable via local settings |
| `pluginConfigs…options.trustgate_mcp_url` | Pre-fills plugin `userConfig` so `${user_config.trustgate_mcp_url}` resolves without a prompt |

`pluginConfigs` shape **must** nest values under `options` ([settings-reference](https://code.claude.com/docs/en/settings-reference#pluginconfigs)).
Project `.claude/settings.json` cannot supply `pluginConfigs`.

## 4. Still required outside this file

| Item | Why |
| --- | --- |
| GitHub **release** of this repo with binaries | Bootstrap / Kandji download `trustguard-claude-code_…` |
| Feature work on **`main`** (or the ref the marketplace clones) | Marketplace source is the GitHub default branch unless you set `ref` |
| Kandji collector + binary | Hooks need `tgk_…` and a runnable binary |
| Per-user **OAuth** to TrustGate | First `/mcp` connect; not stored in managed settings |
| Claude Code recent enough for plugins + `userConfig` | Validate on a pilot Mac (`claude --version`) |

## 5. Verify on a pilot Mac

```bash
# Policy loaded
# In Claude Code: /status → Setting sources includes Enterprise managed settings (file)

# Marketplace + plugin
claude plugin marketplace list
claude plugin list
# expect trustguard@neuraltrust enabled

# MCP URL substituted (not the literal ${user_config…})
# In session: /mcp → TrustGate → complete OAuth once → tools listed

# Hooks + collector
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"pilot"}' \
  | trustguard-claude-code hook
# TrustGuard activity: source.application=claude-code-plugin
```

## 6. Org rollout checklist

- [ ] Merge plugin branch to the marketplace GitHub default branch
- [ ] Tag release `vX.Y.Z` with multi-arch binaries + checksums in bootstrap scripts
- [ ] TrustGuard: Claude Code / IDE collector → `tgk_…` + data-plane URL
- [ ] TrustGate Connect: MCP URL for the org consumer
- [ ] Fill `managed-settings.json` MCP URL (this directory)
- [ ] Kandji: install script CONFIG (`tgk_…`) + optional Claude managed-settings deploy
- [ ] Pilot Blueprint → `/status`, `/mcp`, hook probe, TrustGuard traffic
- [ ] Expand Blueprint to full org
