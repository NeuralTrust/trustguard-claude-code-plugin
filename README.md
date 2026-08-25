# TrustGuard for Claude Code

AI firewall for [Claude Code](https://code.claude.com) via **lifecycle hooks**,
plus a bundled **TrustGate MCP** connector (URL + OAuth).

Same model as the [Cursor](https://github.com/NeuralTrust/trustguard-cursor-plugin)
and [Codex](https://github.com/NeuralTrust/trustguard-codex-plugin) plugins:
local hooks call `trustguard-claude-code` → TrustGuard `POST /v1/evaluate`.

> **Claude Enterprise Inference Hooks** (`/v1/evaluate/claude`) are a separate
> path. This plugin is for teams **without** org-level Inference Hooks (or in
> addition to them, with `source.application=claude-code-plugin` gates).

## Org-wide install (managed) — primary path

Two layers. Details and checklist: **[docs/enterprise.md](./docs/enterprise.md)**.

| Layer | Delivers | Artifact |
| --- | --- | --- |
| **Claude managed settings** | Marketplace, force-enable plugin, TrustGate MCP URL | [`mdm/claude/managed-settings.json`](./mdm/claude/managed-settings.json) |
| **Kandji / MDM** | Collector `tgk_…` + hook binary | [`mdm/kandji/`](./mdm/kandji/) |

### 1. Claude managed settings

Place on every Mac (or push the same keys via claude.ai server-managed settings):

```
/Library/Application Support/ClaudeCode/managed-settings.json
```

```json
{
  "extraKnownMarketplaces": {
    "neuraltrust": {
      "source": {
        "source": "github",
        "repo": "NeuralTrust/trustguard-claude-code-plugin"
      },
      "autoUpdate": true
    }
  },
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

- `pluginConfigs` values must sit under **`options`**.
- MCP auth is **OAuth** (URL only). Users complete OAuth once in `/mcp`.
- **Never** use “Add custom connector” for TrustGate.

Kandji can write this file: set `TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS=1` and
`TRUSTGATE_MCP_URL=…` on the install script. See [`mdm/claude/README.md`](./mdm/claude/README.md).

### 2. Collector key + binary (Kandji)

```bash
# See mdm/kandji/README.md — Custom Script installs:
#   /Library/Application Support/TrustGuard/claude-code.json   (tgk_… locked)
#   /Library/Application Support/TrustGuard/bin/trustguard-claude-code
```

Create a **Claude Code / IDE** collector in TrustGuard (`tgk_…`). Do not reuse
Inference Hook secrets (`whsec_…`).

### 3. Verify (pilot)

```text
/status          → Enterprise managed settings (file|remote|…)
claude plugin list → trustguard@neuraltrust enabled
/mcp             → TrustGate → OAuth → tools
```

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"pilot"}' \
  | trustguard-claude-code hook
# TrustGuard: source.application=claude-code-plugin
```

## Credentials map

| Secret | Where |
| --- | --- |
| TrustGuard collector `tgk_…` | Kandji / `~/.trustguard/claude-code.json` / env — **not** Plugins UI |
| TrustGate MCP URL | `pluginConfigs` in managed settings (or prompt on interactive install) |

## Dogfood / single machine (not org)

```bash
make install-local
claude plugin marketplace add NeuralTrust/trustguard-claude-code-plugin
claude plugin install trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp
```

Or `claude --plugin-dir ./trustguard` from a clone.

## Plugin shape (reference)

```json
"userConfig": {
  "trustgate_mcp_url": { "type": "string", "title": "TrustGate MCP URL", "required": true }
},
"mcpServers": {
  "TrustGate": {
    "type": "http",
    "url": "${user_config.trustgate_mcp_url}"
  }
}
```

## Event → evaluation mapping

| Claude Code event | Protocol | Direction | On block |
| --- | --- | --- | --- |
| `UserPromptSubmit` | `llm` | input | `decision: "block"` |
| `PreToolUse` (`Bash`) | `all` | input | `permissionDecision: "deny"` |
| `PreToolUse` (other / MCP tools) | `mcp` tools/call | input | same deny |
| `PostToolUse` | `mcp` result | output | `decision: "block"` + untrusted guidance |

Stamps: `collector.type=ide`, `source.application=claude-code-plugin`,
`consumer_id` prefixed `claude-code:`.

## Layout

| Path | Role |
| --- | --- |
| `trustguard/` | Plugin (manifest, hooks, skill) |
| `.claude-plugin/marketplace.json` | Marketplace catalog (`neuraltrust`) |
| `cli/` | `trustguard-claude-code` binary |
| `mdm/claude/` | Org Claude managed-settings template |
| `mdm/kandji/` | macOS MDM: binary + collector (+ optional Claude settings) |

```bash
make build && make test && make install-local
```

## License

Apache-2.0 — see [`LICENSE`](./LICENSE).
