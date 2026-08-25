---
name: setup-trustguard
description: Configure the TrustGuard collector key and the TrustGate MCP URL. Use when the user enables Trustguard, sees a locked ${user_config…} URL in Add custom connector, or TrustGate is missing in /mcp.
---

# Configure TrustGuard + TrustGate

| What | Where |
| --- | --- |
| TrustGuard collector `tgk_…` | `~/.trustguard/claude-code.json` or Kandji — never Plugins UI |
| TrustGate MCP URL | Plugin `userConfig` via `/plugin install` — never “Add custom connector” |

## Wrong surface (ignore)

If Claude.ai / Desktop shows **Add custom connector** with URL
`${user_config.trustgate_mcp_url}` grayed out, that is **not** the plugin
`userConfig` form. Cancel it. The plugin already owns TrustGate; reinstall or
enable the plugin so Claude substitutes the value.

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

## 2. Install the plugin (sets MCP URL)

```text
/plugin install trustguard@neuraltrust
```

Claude prompts for **TrustGate MCP URL** (`https://host/consumer-slug/mcp`).
OAuth only — no API key.

CLI:

```bash
claude plugin install trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp
```

Local path while developing:

```text
/plugin install /path/to/trustguard-claude-code-plugin/trustguard
```

Then `/reload-plugins` if needed. Complete OAuth from `/mcp`.

### Org-wide (no per-user prompt)

Managed settings (`pluginConfigs` uses nested `options`):

```json
{
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

## 3. Verify

- `/mcp` → TrustGate connected (OAuth done).
- Hooks fire; TrustGuard shows `source.application=claude-code-plugin`.

`tgk_…` is only the collector key. Never put it on the MCP URL.
