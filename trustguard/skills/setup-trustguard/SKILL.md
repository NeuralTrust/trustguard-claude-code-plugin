---
name: setup-trustguard
description: Configure the TrustGuard collector key and the TrustGate MCP URL for this plugin. Use when the user enables Trustguard, asks where to enter the MCP URL or tgk_ key, or TrustGate is missing / not configured in /mcp.
---

# Configure TrustGuard + TrustGate

| What | Where |
| --- | --- |
| TrustGuard collector `tgk_…` (hooks) | `~/.trustguard/claude-code.json` or Kandji MDM |
| TrustGate MCP URL + optional key | Plugin `userConfig` — prompted on enable |

## 1. Collector key (hooks / firewall)

```bash
mkdir -p ~/.trustguard && chmod 700 ~/.trustguard
cat > ~/.trustguard/claude-code.json <<'EOF'
{
  "data_url": "https://YOUR_TRUSTGUARD_DATA_PLANE",
  "api_key": "tgk_YOUR_COLLECTOR_KEY",
  "fail_mode": "closed"
}
EOF
chmod 600 ~/.trustguard/claude-code.json
```

Enterprise: Kandji writes `/Library/Application Support/TrustGuard/claude-code.json` (locked).

## 2. TrustGate MCP URL — plugin userConfig

Declared in `plugin.json` as `userConfig.trustgate_mcp_url` and substituted into
the bundled HTTP server as `${user_config.trustgate_mcp_url}` (official Claude
Code pattern for plugin MCP URLs).

### First enable (prompt)

Claude Code asks for the values when the plugin is enabled. Fill:

- **TrustGate MCP URL** — required (`https://host/consumer-slug/mcp`)
- **TrustGate MCP API key** — optional consumer key (not `tgk_…`)
- **TrustGate gateway slug** — optional hybrid / private DP

### Non-interactive (CLI)

```bash
claude plugin install trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp \
  --config trustgate_mcp_api_key=YOUR_CONSUMER_KEY
```

If already installed, re-run configure from the TUI: `/plugin` → Installed →
**trustguard** → configure / set options, then `/reload-plugins`.

### Desktop / Org Plugins

Use the plugin options form when Claude prompts at enable time. Do **not** type
the URL into the generic “Add custom connector” dialog — that surface is for
user-added connectors, not plugin `userConfig`, and often shows the raw
`${user_config…}` placeholder.

Values live under `pluginConfigs` in user settings (non-sensitive) and the OS
keychain / `~/.claude/.credentials.json` (sensitive). Project
`.claude/settings.json` does **not** supply `pluginConfigs`.

## 3. Verify

- `/mcp` → **TrustGate** connected and listing tools.
- Hooks:

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"t1"}' \
  | trustguard-claude-code hook
```

Key mix-ups: `tgk_…` = collector (file/MDM); consumer key = MCP
`trustgate_mcp_api_key`; `whsec_…` = never here.
