---
name: setup-trustguard
description: Configure TrustGuard collector key (file/MDM) and TrustGate MCP URL (plugin options). Use when enabling Trustguard or hooks/MCP are not working.
---

# Configure TrustGuard + TrustGate

Two different credentials, two places:

| What | Where you enter it |
| --- | --- |
| TrustGuard collector `tgk_…` | File or Kandji — **not** the Plugins form |
| TrustGate MCP URL (+ optional key) | **Plugins → Trustguard → Customize / Configure options** |

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

Enterprise: Kandji script writes  
`/Library/Application Support/TrustGuard/claude-code.json` (locked).

Do **not** use `whsec_…` or the TrustGate MCP consumer key here.

## 2. TrustGate MCP URL (Connectors)

In Claude:

1. **Plugins → Trustguard**
2. Open **Customize** or the plugin menu → **Configure options**
3. Fill:
   - **TrustGate MCP URL** — `https://{host}/{consumer-slug}/mcp` from TrustGate Connect
   - **TrustGate MCP API key** — optional consumer key (not `tgk_…`)
   - **Gateway slug** — only hybrid / private DP

That is how you **type the URL**. The Connectors tab then uses the saved value for the **TrustGate** server.

CLI equivalent:

```bash
claude plugin enable trustguard@neuraltrust \
  --config trustgate_mcp_url=https://host/slug/mcp \
  --config trustgate_mcp_api_key=YOUR_CONSUMER_KEY
```

If **Add connector** shows a literal `${user_config…}` string, cancel that dialog and use **Configure options** instead — that form is the real URL field.

## 3. Binary (if needed)

```bash
trustguard-claude-code version \
  || ls "/Library/Application Support/TrustGuard/bin/" \
  || ls ~/.trustguard/bin/
```

## 4. Verify hooks

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"t1"}' \
  | trustguard-claude-code hook
```
