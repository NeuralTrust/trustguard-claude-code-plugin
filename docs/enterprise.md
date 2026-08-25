# Enterprise deployment notes

## Kandji (macOS) — recommended

Use the ready-made Custom Script:

- **[mdm/kandji/README.md](../mdm/kandji/README.md)** — Library Item steps  
- **`mdm/kandji/install-trustguard-claude-code.sh`** — install binary + managed key  
- **`mdm/kandji/audit-trustguard-claude-code.sh`** — optional Audit companion  

That path is the supported org rollout for collector `tgk_…` + binary.

## Managed config

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

## Plugin distribution

Kandji does **not** enable the Claude plugin. Separately:

- Org marketplace + enable **trustguard**, or  
- `claude --plugin-dir` for dogfood  

## Collector key is not in the Claude Plugins UI

Org **Plugins → Trustguard** shows Skills / Connectors / Hooks only. Credentials
come from the managed JSON (Kandji) or `~/.trustguard/claude-code.json` (BYO).

TrustGate MCP: Claude **Connectors** with a real HTTPS MCP URL — not the
collector key file.

## Inference Hooks vs this plugin

Do **not** point this plugin at an Anthropic Inference Hook secret. Use a
normal TrustGuard collector API key (`tgk_…`) for the Claude Code / IDE
collector type.

Inference Hook deliveries use `source.application` values such as `claude-ai`
and `claude-code`. This plugin stamps `source.application=claude-code-plugin`
so policy gates can treat local-hook traffic separately if both paths are on.
