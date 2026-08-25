---
name: setup-trustguard
description: Configure the TrustGuard collector key and the TrustGate MCP URL for this plugin. Use when the user enables Trustguard, asks where to enter the MCP URL or tgk_ key, or /mcp shows TrustGate as "not configured".
---

# Configure TrustGuard + TrustGate

Two credentials, two places. Neither goes in the **Add custom connector** dialog.

| What | Where |
| --- | --- |
| TrustGuard collector `tgk_…` (hooks) | `~/.trustguard/claude-code.json` or Kandji MDM |
| TrustGate MCP URL + optional key | `env` block in `~/.claude/settings.json` |

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

## 2. TrustGate MCP — environment variables

The bundled TrustGate connector reads `${TRUSTGATE_MCP_URL:-}`. Until the
variable is set it shows as `not configured` in `/mcp` — that is expected, not
an error. Set the variables in the `env` block of `~/.claude/settings.json`:

```json
{
  "env": {
    "TRUSTGATE_MCP_URL": "https://HOST/CONSUMER-SLUG/mcp",
    "TRUSTGATE_MCP_API_KEY": "YOUR_CONSUMER_KEY"
  }
}
```

Merge into the existing file if it already has other keys. Optional:
`TRUSTGATE_GATEWAY_SLUG` for hybrid / private data planes.

Restart the session (or `/reload-plugins`), then check `/mcp`: **TrustGate**
should show `connected` and list its tools.

Alternatives: export the same variables in your shell profile, or push them
org-wide through managed settings (Kandji/MDM) — same `env` block, in
`/Library/Application Support/ClaudeCode/managed-settings.json` on macOS.

Do **not** use `${user_config…}` values or the "Add custom connector" dialog
for this server; plugin `userConfig` substitution in MCP configs fails
silently (known Claude Code issue) and the dialog locks plugin URLs.

## 3. Verify

- `/mcp` → **TrustGate** `connected` (after env vars set + session restart).
- Hooks:

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"t1"}' \
  | trustguard-claude-code hook
```

Key mix-ups to avoid: `tgk_…` = TrustGuard collector (file/MDM only);
consumer key = TrustGate MCP (`TRUSTGATE_MCP_API_KEY`); `whsec_…` = never here.
