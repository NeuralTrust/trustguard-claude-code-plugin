---
name: setup-trustguard
description: Configure TrustGuard collector hooks and point TrustGate MCP to org Connectors. Use when TrustGate shows as plugin-provided, managed settings lack enabledPlugins, or hooks lack tgk_.
---

# TrustGuard hooks + TrustGate org MCP

## Separation (do not mix)

| Layer | Where |
| --- | --- |
| **TrustGate MCP (all products)** | claude.ai **Organization → Connectors** (always on for the org) |
| **Plugin (Code hooks only)** | Claude managed settings — `enabledPlugins` only |
| **Collector `tgk_…` + binary** | Kandji — `mdm/kandji/` |

This plugin does **not** ship MCP. If Connectors shows TrustGate as
“Provided by the Trustguard plugin”, the plugin is outdated — update the
marketplace / reinstall, and use the **org** connector instead.

## Org managed settings (hooks)

```json
{
  "enabledPlugins": { "trustguard@neuraltrust": true },
  "extraKnownMarketplaces": {
    "neuraltrust": {
      "source": {
        "source": "github",
        "repo": "NeuralTrust/trustguard-claude-code-plugin"
      },
      "autoUpdate": true
    }
  }
}
```

No `pluginConfigs`. No MCP URL here.

Path on macOS (file path only if MDM deploys it):  
`/Library/Application Support/ClaudeCode/managed-settings.json`.  
Server-managed settings do not create that file.

## TrustGate MCP

Owner: **Organization settings → Connectors → Add → Custom → Web**  
URL: `https://HOST/CONSUMER-SLUG/mcp`  
Users: Connect (OAuth) once per account.

## Collector (never in Plugins / Connectors UI)

```bash
cat "/Library/Application Support/TrustGuard/claude-code.json"
```

## Local dogfood

```bash
claude plugin install trustguard@neuraltrust

mkdir -p ~/.trustguard && cat > ~/.trustguard/claude-code.json <<'EOF'
{
  "data_url": "https://YOUR_DATA_PLANE",
  "api_key": "tgk_…",
  "fail_mode": "closed"
}
EOF
chmod 600 ~/.trustguard/claude-code.json
```

Add TrustGate under Connectors (user or org), not via plugin config.

## Verify

- Org Connectors → TrustGate connected on claude.ai / Desktop / Code
- `/status` → Enterprise managed settings
- `claude plugin list` → `trustguard@neuraltrust`
- `/mcp` → TrustGate as **org** connector (not plugin-provided)
- Hook probe → TrustGuard `source.application=claude-code-plugin`
