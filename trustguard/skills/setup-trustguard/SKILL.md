---
name: setup-trustguard
description: Configure TrustGuard collector key and TrustGate MCP URL for the Claude Code plugin.
---

# Configure TrustGuard + TrustGate

## Collector key (hooks) — not in the Connectors dialog

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

Or Kandji MDM → `/Library/Application Support/TrustGuard/claude-code.json`.

## TrustGate MCP URL — paste in Connectors

Desktop **does not** resolve `${user_config…}` in the Add connector form. The plugin
ships a TrustGate connector with URL prefilled as `https://` so the field is valid
to edit.

1. **Plugins → Trustguard → Connectors → TrustGate → Add** (or Configure)
2. In the **URL** field, replace `https://` with your full endpoint from TrustGate Connect:

   `https://{host}/{consumer-slug}/mcp`

3. If you need an API key header, use **Advanced** / auth fields for the consumer
   key — **not** the TrustGuard `tgk_…` collector key.
4. **Add**

### Claude Code CLI (alternative)

```bash
claude mcp add --transport http TrustGate "https://{host}/{consumer-slug}/mcp" \
  --header "X-AG-API-Key: YOUR_CONSUMER_KEY"
```

## Verify hooks

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"t1"}' \
  | trustguard-claude-code hook
```
