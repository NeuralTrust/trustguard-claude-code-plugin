---
name: setup-trustguard
description: Configure TrustGuard collector and TrustGate MCP for org managed rollout or local dogfood. Use when enabledPlugins/pluginConfigs are missing, Add custom connector shows ${user_config…}, or hooks lack tgk_.
---

# TrustGuard + TrustGate (org managed first)

## Org path (preferred)

| Layer | Where |
| --- | --- |
| Plugin + MCP URL | Claude managed settings — see repo `mdm/claude/managed-settings.json` |
| Collector `tgk_…` + binary | Kandji — `mdm/kandji/` |

Managed settings must include:

```json
{
  "enabledPlugins": { "trustguard@neuraltrust": true },
  "pluginConfigs": {
    "trustguard@neuraltrust": {
      "options": { "trustgate_mcp_url": "https://HOST/SLUG/mcp" }
    }
  }
}
```

Path on macOS: `/Library/Application Support/ClaudeCode/managed-settings.json`.

**Wrong surface:** “Add custom connector” with locked `${user_config.trustgate_mcp_url}` —
cancel it. The plugin already owns TrustGate.

Collector key is **never** in the Plugins UI:

```bash
# MDM path (locked)
cat "/Library/Application Support/TrustGuard/claude-code.json"
```

## Local dogfood only

```bash
claude plugin install trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp

mkdir -p ~/.trustguard && cat > ~/.trustguard/claude-code.json <<'EOF'
{
  "data_url": "https://YOUR_DATA_PLANE",
  "api_key": "tgk_…",
  "fail_mode": "closed"
}
EOF
chmod 600 ~/.trustguard/claude-code.json
```

## Verify

- `/status` → Enterprise managed settings (org)
- `claude plugin list` → `trustguard@neuraltrust`
- `/mcp` → TrustGate OAuth once
- Hook probe → TrustGuard `source.application=claude-code-plugin`
