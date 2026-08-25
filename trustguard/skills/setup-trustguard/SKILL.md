---
name: setup-trustguard
description: Configure TrustGuard collector key and add TrustGate MCP as a custom Connector with an editable URL.
---

# Configure TrustGuard + TrustGate

## Why MCP is not inside this plugin

Claude Desktop **locks** the URL field when a connector comes from a plugin
`mcpServers` entry. You cannot type a per-org TrustGate URL there. So this
plugin only ships **hooks** (firewall). MCP is a normal custom connector.

## 1. Collector key (hooks)

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

Or Kandji → `/Library/Application Support/TrustGuard/claude-code.json`.

## 2. TrustGate MCP — custom connector (URL editable)

### Desktop / Claude.ai

1. Open **Customize → Connectors** (sidebar), **not** the plugin Connectors tab  
   (or **Settings → Connectors**)
2. **Add custom connector** / **Add**
3. **Name:** `TrustGate` (any label)
4. **URL:** paste the full endpoint from TrustGate **Connect**  
   `https://{host}/{consumer-slug}/mcp`  
   This field is **editable** on a hand-added connector.
5. Auth: consumer API key if required (not TrustGuard `tgk_…`)
6. **Add**

### Claude Code CLI

```bash
claude mcp add --transport http TrustGate "https://{host}/{consumer-slug}/mcp" \
  --header "X-AG-API-Key: YOUR_CONSUMER_KEY"
```

## 3. Verify hooks

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"t1"}' \
  | trustguard-claude-code hook
```
