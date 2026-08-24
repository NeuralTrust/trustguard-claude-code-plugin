# Enterprise deployment notes

## Managed config

Ship a JSON file with the org Claude Code collector key. When `api_key` is set
in this file, the binary locks `api_key`, `data_url`, and `fail_mode` against
user and env overrides.

| OS | Path |
|---|---|
| macOS | `/Library/Application Support/TrustGuard/claude-code.json` |
| Linux | `/etc/trustguard/claude-code.json` |
| Windows | `%ProgramData%\TrustGuard\claude-code.json` |

```json
{
  "data_url": "https://data.example.neuraltrust.ai",
  "api_key": "tgk_…",
  "fail_mode": "closed",
  "consumer_id": "claude-code:corp-sso-hint"
}
```

Soft prefs (`timeout_ms`, `transform_action`, `events`, `report_notice`) may
still live in `~/.trustguard/claude-code.json`.

## Binary

Deploy `trustguard-claude-code` to PATH or `~/.trustguard/bin`. The plugin
bootstrap prefers PATH, then `~/.trustguard/bin/trustguard-claude-code`, then
the pinned release download (SHA-256 verified).

## Plugin distribution

- Private marketplace: host this repo (or a fork) and
  `/plugin marketplace add <org>/<repo>`.
- Or pin `claude --plugin-dir` / managed settings to a synced checkout.

## Inference Hooks vs this plugin

Do **not** point this plugin at an Anthropic Inference Hook secret. Use a
normal TrustGuard collector API key (`tgk_…`) for the Claude Code / IDE
collector type.

Inference Hook deliveries use `source.application` values such as `claude-ai`
and `claude-code`. This plugin stamps `source.application=claude-code-plugin`
so policy gates can treat local-hook traffic separately if both paths are on.
