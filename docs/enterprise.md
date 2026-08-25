# Enterprise deployment notes

## Kandji (macOS) — collector + binary

Use the ready-made Custom Script:

- **[mdm/kandji/README.md](../mdm/kandji/README.md)** — Library Item steps
- **`mdm/kandji/install-trustguard-claude-code.sh`** — install binary + managed key
- **`mdm/kandji/audit-trustguard-claude-code.sh`** — optional Audit companion

That path is the supported org rollout for collector `tgk_…` + binary.

## Managed config (TrustGuard collector)

When `api_key` is set in the system file, the binary locks `api_key`,
`data_url`, and `fail_mode` against user file and env overrides.

| OS | Path |
|---|---|
| macOS | `/Library/Application Support/TrustGuard/claude-code.json` |
| Linux | `/etc/trustguard/claude-code.json` |
| Windows | `%ProgramData%\TrustGuard\claude-code.json` |

```json
{
  "data_url": "https://data.example.neuraltrust.ai",
  "api_key": "tgk_…",
  "fail_mode": "closed"
}
```

Soft prefs (`timeout_ms`, `transform_action`, `events`, `report_notice`) may
still live in `~/.trustguard/claude-code.json`.

## Binary

| Preference order (bootstrap) | Location |
|---|---|
| 1 | `trustguard-claude-code` on `PATH` |
| 2 | `~/.trustguard/bin/trustguard-claude-code` (local) |
| 3 | Versioned download under `~/.trustguard/bin` |
| MDM | `/Library/Application Support/TrustGuard/bin/trustguard-claude-code` + PATH symlink |

## Plugin + TrustGate MCP (Claude managed settings)

Kandji does **not** enable the Claude plugin. Deploy Claude Code
[managed settings](https://code.claude.com/docs/en/managed-settings) so the
plugin is on and the MCP URL is pre-filled (`userConfig` →
`${user_config.trustgate_mcp_url}`):

```json
{
  "enabledPlugins": {
    "trustguard@neuraltrust": true
  },
  "extraKnownMarketplaces": {
    "neuraltrust": {
      "source": {
        "source": "github",
        "repo": "NeuralTrust/trustguard-claude-code-plugin"
      }
    }
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

| Key | Role |
| --- | --- |
| `enabledPlugins` | Force **trustguard@neuraltrust** on for every user |
| `extraKnownMarketplaces` | Register this GitHub marketplace org-wide |
| `pluginConfigs.*.options` | Pre-set `userConfig` (MCP URL). Shape from [settings-reference](https://code.claude.com/docs/en/settings-reference#pluginconfigs) |

`pluginConfigs` is **user or managed** only. Project settings are ignored so a
cloned repo cannot inject plugin options into MCP/hooks.

**Do not** have users open “Add custom connector” for TrustGate. That UI is
unrelated to plugin `userConfig` and shows the locked
`${user_config.trustgate_mcp_url}` placeholder. Install/enable via `/plugin`
or managed `enabledPlugins` only.

Per-user interactive path (no managed URL):

```bash
claude plugin install trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp
```

Auth to the MCP endpoint is OAuth (no API key in the plugin).

## Collector key is not in the Claude Plugins UI

Org **Plugins → Trustguard** shows Skills / Connectors / Hooks. The collector
`tgk_…` never appears there — it comes from the managed TrustGuard JSON
(Kandji) or `~/.trustguard/claude-code.json`.

## Inference Hooks vs this plugin

Do **not** point this plugin at an Anthropic Inference Hook secret. Use a
normal TrustGuard collector API key (`tgk_…`) for the Claude Code / IDE
collector type.

Inference Hook deliveries use `source.application` values such as `claude-ai`
and `claude-code`. This plugin stamps `source.application=claude-code-plugin`
so policy gates can treat local-hook traffic separately if both paths are on.
