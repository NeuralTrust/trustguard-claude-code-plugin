---
name: setup-trustguard
description: Configure the TrustGuard collector key and the TrustGate MCP URL for this plugin. Use when the user enables Trustguard, asks where to enter the MCP URL or tgk_ key, or TrustGate is missing / not configured in /mcp.
---

# Configure TrustGuard + TrustGate

| What | Where |
| --- | --- |
| TrustGuard collector `tgk_…` (hooks) | `~/.trustguard/claude-code.json` or Kandji MDM |
| TrustGate MCP URL | Plugin `userConfig` — prompted on enable; auth is OAuth |

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

## 2. TrustGate MCP URL — plugin userConfig (URL only)

Declared in `plugin.json` as `userConfig.trustgate_mcp_url` and substituted as
`${user_config.trustgate_mcp_url}`. No API key or gateway slug — Claude Code
completes OAuth against the MCP endpoint.

### First enable (prompt)

Claude Code asks for **TrustGate MCP URL** (`https://host/consumer-slug/mcp`).

### Non-interactive (CLI)

```bash
claude plugin install trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp
```

If already installed: `/plugin` → Installed → **trustguard** → configure
options, then `/reload-plugins`. Complete OAuth from `/mcp` if prompted.

Do **not** paste the URL into the generic “Add custom connector” dialog.

## 3. Verify

- `/mcp` → **TrustGate** connected (OAuth done) and listing tools.
- Hooks:

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"t1"}' \
  | trustguard-claude-code hook
```

`tgk_…` is only the TrustGuard collector key (file/MDM). Never put it on the MCP URL.
