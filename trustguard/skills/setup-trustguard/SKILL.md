---
name: setup-trustguard
description: Configure the TrustGuard collector key and the TrustGate MCP URL for this plugin. Use when the user enables Trustguard, asks where to enter the MCP URL or tgk_ key, or the TrustGate connector shows an unresolved placeholder.
---

# Configure TrustGuard + TrustGate

Two credentials, two places. Neither goes in the **Add custom connector** dialog.

| What | Where |
| --- | --- |
| TrustGuard collector `tgk_…` (hooks) | `~/.trustguard/claude-code.json` or Kandji MDM |
| TrustGate MCP URL + optional key | **Plugin options** (`userConfig`) — see below |

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

## 2. TrustGate MCP URL — plugin options

The TrustGate connector reads `${user_config.trustgate_mcp_url}`. Claude Code
substitutes it at session start once the option is set. Set it one of these ways:

### Claude Code (terminal) — most reliable

```bash
claude plugin enable trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp \
  --config trustgate_mcp_api_key=YOUR_CONSUMER_KEY
```

Or interactively: run `/plugin`, open **Installed → trustguard → Configure options**,
fill **TrustGate MCP URL**, save, then `/reload-plugins` (or restart the session).

### Desktop app

**Plugins → Trustguard → Customize** opens the same options form when available.

### Do NOT use "Add custom connector"

That dialog shows the raw `${user_config…}` placeholder, locks the URL field for
plugin-provided servers, and is not how plugin MCP servers are configured. Close
it and use Configure options instead.

## 3. Verify

- `/mcp` in a session → **TrustGate** should list tools (after the URL is set).
- Hooks:

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"t1"}' \
  | trustguard-claude-code hook
```

Key mix-ups to avoid: `tgk_…` = TrustGuard collector (file/MDM only);
consumer key = TrustGate MCP (`trustgate_mcp_api_key`); `whsec_…` = never here.
